# WPPP Engineering Handoff

Last updated: 2026-08-19 local time.

This is the dense implementation reference for the current WPPP hardware. It
is not the issue ledger or proof that a particular run passed. See
[`docs/README.md`](docs/README.md) for document ownership.

## Very Short Summary

The production top instantiates two `wppprefetch_rw_pipeline_v2` engines, one
per HDM channel. Software supplies up to eight packed hints by writing a
configured hint-mechanism page. The AFU unpacks one 64-bit hint per cycle and
advances the engine selector for every physical slot. Each nonzero-count slot
contains a 48-bit userspace VA and requests a contiguous sequence of 64-byte
cachelines. A translation stage splits it by 4 KiB page, looks up a banked
cache, and passes only translated PA fragments inside the configured PA range.
An engine reads each accepted line using a device-biased AXI request, maps its
rotating 10-bit request ID back to the original address, and issues an NCP
write of the returned data to that same PA.

The operation is a read/writeback used to pull the addressed line toward the
host. It is not a general stream prefetcher and does not place response data in
a software-visible buffer.

## Active Production Path

| Stage | Active source | Contract |
| --- | --- | --- |
| Hint snoop | `common/prefetch/wppp_hint_snoop.sv`, instantiated by `common/afu/afu_top.sv` | On a channel-0 write-address match within the configured 4 KiB hint page, captures one 512-bit line, emits eight decoded slots, and counts an overlapping line write as a drop. |
| Translation front end | `common/prefetch/wppp_translation_stage.sv` | Queues nonzero-count hints, splits at 4 KiB, coalesces misses for 128-cycle service, checks translated PA fragments, and holds a hit until the selected engine FIFO is ready. |
| Translation cache | `common/prefetch/wppp_translation_cache*.sv` | Four banks x 16K sets x eight ways, per-set RR, inferred RAM, and a 16K-cycle POR/CSR row sweep. HPPB is disconnected. |
| Top integration | `ed_top_wrapper_typ2.sv` | Selects production 16/42 translation mode; enables WPPP with `csr_prefetch_interval[31]`; arbitrates the two engines with HPPB only at the final AXI layer. |
| Read issue | `common/prefetch/wppp_hb_req.sv` | Queues packed hints, transfers each FIFO head into an active context, expands it into 64-byte reads, and allocates a rotating 10-bit request ID when AR handshakes. |
| Address ownership | `common/prefetch/wppp_lut.sv` | Tracks 1024 valid IDs and stores ID-to-address mappings in `w4096_d64`; a response clears its valid bit. |
| Read response | `common/prefetch/wppp_hb_resp.sv` | Keeps R ready, looks up `rid[9:0]`, and pipelines valid response payload plus recovered address. |
| Writeback | `common/prefetch/wppp_ncp.sv` (`wppp_ncp_pipe`) | Queues payloads, handshakes AW and then W, and counts successful W handshakes. |
| Pipeline wrapper | `common/prefetch/wpprefetch_rw_pipe_v2.sv` | Connects the four stages. `NCP_PIPE_ON=1`; the write-protection filter is bypassed. |

The older `prefetch_*`, `wpprefetch_rw`, and
`wppprefetch_rw_pipeline` implementations are retained source history but are
not instantiated by the active top.

## Hint and Address Contract

A packed hint is:

```text
bits [63:58]  reserved; software writes zero
bits [57:42]  cacheline count (16 bits; first-version maximum 128)
bits [41:0]   VA[47:6]
```

The snoop reconstructs the aligned VA as `{hint[41:0], 6'b0}`. Count zero is
the only unused-slot marker in production; VA zero is not used to qualify
validity. Reserved bits or a count above 128 make a nonzero slot invalid. The
selector advances through all eight positions even when a position is unused.

At the host-facing boundary, this project explicitly assumes paired AXI write
channels: AW and W are presented and accepted in the same clock cycle. The
hint snoop relies on that rule by qualifying capture with AWVALID and sampling
WDATA in that cycle. It does not buffer or independently associate host AW and
W, so a producer that separates those handshakes is outside the current
integration contract. WPPP's outgoing NCP writer is different: it intentionally
handshakes AW before offering W.

Translation is `PA = VA - csr_wppp_translation_offset`; the software-supplied
offset is page aligned, changes only at very low frequency, and requires a
cache flush after a change. Every page fragment preserves VA `[11:0]`. The PA
range rule is:

```text
cxl_start_pa <= translated fragment
translated fragment end <= cxl_start_pa + csr_addr_ub
```

The entire fragment is checked in a 65-bit domain after translation. It is
dropped rather than clipped when outside the range. Cache admission does not
depend on this guard. `csr_addr_lb` remains connected but unused, while
`csr_addr_ub` is a span, not an absolute endpoint.

For cacheline index `n`, the read address is `translated_address + n * 64`.

## AXI and Ownership Contract

- Reads are single-beat, 64-byte, fixed bursts: `arlen=0`, `arsize=6`, and
  `arburst=0`.
- The current branch drives `aruser=6'b110000` (device-biased); this intentionally
  differs from the older host-biased implementation.
- Each FIFO head is copied into an active-hint register and popped once. If AR
  is backpressured, a pending register holds VALID, ID, and address stable;
  active count/index state retires only on handshake.
- Only `arid[9:0]` carries WPPP ownership. The LUT blocks reuse while the next
  ID remains valid and naturally supports out-of-order responses.
- `wppp_hb_resp` accepts every `rvalid` because `rready` is tied high. It does
  not currently reject non-OK `rresp`, validate `rlast`, or use `ruser`.
- The write stage emits AW before W and waits independently for each
  handshake. It does not wait for B before starting the next FIFO entry;
  `bready` is tied high.
- NCP writes use all 64 byte strobes and `awuser=7'b0100010`. The local
  `axi_ports.awuser` field is only six bits, so Questa reports a width mismatch
  and the MSB is truncated at this integration boundary. That MSB is zero in
  the current constant, so the numeric value is preserved; the declaration
  mismatch remains an open cleanup/contract issue in `BUG.md`.
- `prefetch_ok_cnt` counts completed W handshakes. It does not prove a
  successful B response. `prefetch_abt_cnt` is tied to zero in v2.

## Capacity and Generated IP

The translation cache holds 524,288 4 KiB mappings (2 GiB coverage): four
banks, 16,384 sets per bank, and eight 64-bit ways. VA `[13:12]` selects bank,
VA `[27:14]` selects set, and VA `[47:28]` is the tag. A 32x8 hashed MSHR
coalesces equal VPNs. A one-entry-per-cycle timing wheel produces the fixed
128-cycle fill service. Cache rows are inferred M20K memories and are cleared
by a timing-friendly sweep rather than reset flops.

The hint FIFO is 73 bits wide and the response-to-NCP FIFO is 588 bits wide.
Both checked-in `.ip` descriptors now request depth 256, despite historical
module names that refer to older shapes. Their descriptors expose 8-bit
`usedw`; active RTL connects only 5 and 7 bits respectively. Those occupancy
signals are debug-only, but the mismatch must be reviewed whenever IP is
regenerated.

The ownership table provides 1024 active ID slots backed by a 4096x64 RAM.
Only the low 1024 entries are addressed. `csr_flush_lut` clears validity but
does not need to erase RAM contents.

## Active Gaps

- The production translation stage rejects an out-of-range PA fragment before
  engine admission. The standalone direct-engine range-head reproducer remains
  relevant to legacy/direct users of the engine interface.
- The new translation path currently has compile/elaboration evidence but no
  directed functional cache-mode regression; see `WPPP-TCACHE-008`.
- The paired AW/W hint-write behavior is an explicit project integration
  assumption, not general AXI-channel support. The AXI integration simulation
  drives and checks that contract, but the RTL has no recovery if a future
  producer violates it.
- The v2 filter path and several legacy status/control ports are bypassed,
  ignored, or undriven. Do not infer behavior from their names without tracing
  the active connections.

See [`BUG.md`](BUG.md) for issue states and
[`wppp_sim/README.md`](wppp_sim/README.md) for verification coverage.

## AXI-Level Integration Harness

`wppp_integration_sim` wraps the extracted production hint snoop, the explicit
legacy/direct branch of `wppp_translation_stage`, both v2 engines, and both
final WPPP/HPPB arbiters. An
AXI-level fake CXL IP forwards device-biased WPPP reads to two queued ports on
a shared fake device MC and terminates NCP writes in separate host/CPU sinks.
Ordinary host traffic traverses the same fake CXL IP, DUT pass-through, and MC.

HPPB remains deliberately inactive: its AXI requester ports use the production
inactive stubs, and the testbench fails on any HPPB request activity. This
boundary verifies the historical 14/50 direct-PA hint path through read/push
completion without simulating CXL link/protocol behavior or an active migration
engine. It does not verify the production 16/42 cache mode. See
[`wppp_integration_sim/README.md`](wppp_integration_sim/README.md) for the
topology, maintained tests, and extension points.

## Workflow Migration Boundary

The simulation tiering, JSON evidence, fresh-report compile checks,
documentation ownership, and best-effort notification behavior were adapted
from `/research/yans3/r1bes_v243_remap`. Its remap-specific RTL tests,
multi-repository Slurm launch/monitor/publish flow, bitstream publication, and
incident history were intentionally not copied. This repository now has a
local, single-project Quartus runner suited to `cxltyp2_ed`.
