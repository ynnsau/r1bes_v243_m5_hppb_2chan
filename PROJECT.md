# WPPP Engineering Handoff

Last updated: 2026-08-18 local time.

This is the dense implementation reference for the current WPPP hardware. It
is not the issue ledger or proof that a particular run passed. See
[`docs/README.md`](docs/README.md) for document ownership.

## Very Short Summary

The production top instantiates two `wppprefetch_rw_pipeline_v2` engines, one
per HDM channel. Software supplies up to eight packed hints by writing a
configured hint-mechanism page. The AFU unpacks one 64-bit hint per cycle and
alternates engines. Each hint requests a contiguous sequence of 64-byte
cachelines. An engine reads each line using a device-biased AXI request, maps
its rotating 10-bit request ID back to the original address, and issues an NCP
write of the returned data to that same address.

The operation is a read/writeback used to pull the addressed line toward the
host. It is not a general stream prefetcher and does not place response data in
a software-visible buffer.

## Active Production Path

| Stage | Active source | Contract |
| --- | --- | --- |
| Hint snoop | `common/prefetch/wppp_hint_snoop.sv`, instantiated by `common/afu/afu_top.sv` | On a channel-0 write-address match within the configured 4 KiB hint page, captures 512-bit write data and emits eight packed hints over eight cycles. |
| Migration filter | `common/hot_page_push/page_tbl_update.sv` | Delays the hint two cycles; suppresses it during an HPPB table update or when its page is marked host-resident. |
| Top integration | `ed_top_wrapper_typ2.sv` | Sends nonzero hints alternately to two WPPP engines; enables them with `csr_prefetch_interval[31]`; arbitrates their AXI traffic with HPPB. |
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
bits [63:50]  cacheline count (14 bits)
bits [49:0]   byte address
```

Although the wrapper port is 16 bits wide, `wppp_hb_req` stores only count
bits `[13:0]`. Address bits `[63:50]` are discarded. A zero output address is
used as "no hint" by the top integration and therefore cannot be enqueued.

At the host-facing boundary, this project explicitly assumes paired AXI write
channels: AW and W are presented and accepted in the same clock cycle. The
hint snoop relies on that rule by qualifying capture with AWVALID and sampling
WDATA in that cycle. It does not buffer or independently associate host AW and
W, so a producer that separates those handshakes is outside the current
integration contract. WPPP's outgoing NCP writer is different: it intentionally
handshakes AW before offering W.

The current range rule is:

```text
start_address_i <= hint_address < start_address_i + address_upper_i
```

`address_lower_i` is connected but unused. `address_upper_i` is treated as a
span from `start_address_i`, not an absolute upper address. The range bounds
are registered. Enable, abort, range, and LUT ownership gate presentation of a
new AR, but cannot withdraw an AR that has already been sampled while stalled.

For cacheline index `n`, the read address is `hint_address + n * 64`. A zero
cacheline count has no useful defined behavior and should not be emitted by
software.

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

- An out-of-range hint remains at the FIFO head forever and blocks later valid
  hints. Reproducer: `RUN_RANGE_HEAD_BLOCK_REPRO`.
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

`wppp_integration_sim` wraps the extracted production hint snoop,
`page_tbl_update`, both v2 engines, and both final WPPP/HPPB arbiters. An
AXI-level fake CXL IP forwards device-biased WPPP reads to two queued ports on
a shared fake device MC and terminates NCP writes in separate host/CPU sinks.
Ordinary host traffic traverses the same fake CXL IP, DUT pass-through, and MC.

HPPB remains deliberately inactive: its table-update input and address arrays
are zero, its AXI requester ports use the production inactive stubs, and the
testbench fails on any HPPB request activity. This boundary verifies hint
injection through read/push completion without simulating CXL link/protocol
behavior or an active migration engine. See
[`wppp_integration_sim/README.md`](wppp_integration_sim/README.md) for the
topology, maintained tests, and extension points.

## Workflow Migration Boundary

The simulation tiering, JSON evidence, fresh-report compile checks,
documentation ownership, and best-effort notification behavior were adapted
from `/research/yans3/r1bes_v243_remap`. Its remap-specific RTL tests,
multi-repository Slurm launch/monitor/publish flow, bitstream publication, and
incident history were intentionally not copied. This repository now has a
local, single-project Quartus runner suited to `cxltyp2_ed`.
