# WPPP Prefetch Module Contract

This directory contains several generations of prefetch RTL. The production
top uses the translation-cache hint front end followed by two instances of the
v2 WPPP read/push pipeline.

## Active Hierarchy

```text
wppp_hint_snoop                 (16/42 hint decode and one-line ingress buffer)
wppp_translation_stage         (FIFO, page splitter, MSHR, delay, PA guard)
  +-- wppp_translation_cache   (4 banks x 16K sets x 8 ways)
        +-- 4 x wppp_translation_cache_bank
  |
  +-- page-local translated fragments to two instances of:
wppprefetch_rw_pipeline_v2
  +-- wppp_hb_req
  |     +-- fifo_32w_73d       (73-bit hint FIFO, configured depth 256)
  +-- wppp_lut
  |     +-- w4096_d64          (ID -> original read address)
  +-- wppp_hb_resp
  +-- one pipeline register
  +-- wppp_ncp_pipe
        +-- fifo_128w_588d     (588-bit response FIFO, configured depth 256)
```

`ed_top_wrapper_typ2.sv` instantiates the pipeline hierarchy twice. The AFU
hint snoop advances the selector through all eight physical slots, including
zero-count slots. The translation stage retains that selector on every page
fragment. HPPB remains a separate AXI client at the final arbiters, but HPPB
migration state has no connection to WPPP hint lookup or cache insertion.

## Module Responsibilities

- `wpprefetch_rw_pipe_v2.sv`: active wrapper. Connects request, ownership,
  response, and NCP stages. The filter is bypassed and `NCP_PIPE_ON` is one.
- `wppp_hint_snoop.sv`: AFU integration block extracted from `afu_top.sv`.
  A write in the configured 4 KiB hint page captures one 512-bit line and
  emits its eight packed 64-bit slots on consecutive cycles. Its production
  decoder implements the 16/42 format below. The buffer is one line deep; a
  matching host write while occupied is dropped and counted.
- `wppp_translation_stage.sv`: queues decoded records, splits them at 4 KiB
  boundaries, looks up each VPN, models miss service with a 32-set/8-way MSHR
  and 128-cycle timing wheel, applies the translated-PA range guard, and holds
  each accepted fragment until its selected engine FIFO is ready.
- `wppp_translation_cache*.sv`: infer the banked 2 GiB-coverage cache. A row
  sweep clears one set in every bank per cycle at POR and CSR flush; there is
  no reset loop over cache RAM.
- `wppp_stats_cdc.sv`: snapshots all 26 64-bit statistics together every 64
  fast-clock cycles and transfers the held snapshot to the CSR clock with a
  request/acknowledge toggle.
- `wppp_hb_req.sv`: accepts `{count,address}` hints, transfers each FIFO head
  into a stable active-hint context, and issues one device-biased 64-byte read
  per cacheline. A backpressured AR is held independently of live enable,
  abort, range, and LUT gating; IDs and cacheline state advance only on the AR
  handshake.
- `wppp_lut.sv`: records the exact accepted AR address under `arid[9:0]` and
  prevents reuse until the corresponding read response consumes it.
- `wppp_hb_resp.sv`: accepts out-of-order responses, obtains the original
  address from the LUT RAM, and aligns it with the payload through two stages.
- `wppp_ncp.sv`: contains both the inactive FSM implementation and active
  `wppp_ncp_pipe`. The active module queues response tuples, sends AW followed
  by W, and increments `success_count` on W handshake.
- `wppp_filter_check.sv`: implemented source but bypassed by the v2 wrapper.

## Stable Invariants

- A hint describes contiguous 64-byte cachelines.
- An AR handshake and LUT insertion are atomic (`write_lut = arvalid && arready`).
- FIFO-head ownership transfers once into the active-hint register. The active
  hint retires only after its final AR handshake.
- Once ARVALID has been sampled with ARREADY low, ARVALID, ARID, ARADDR, and
  attributes remain stable until acceptance.
- A response ID is not reusable while its valid bit is set.
- Response ordering need not match request ordering.
- Each accepted response produces at most one NCP FIFO entry.
- NCP AW must complete before its W payload is offered.
- `csr_flush_lut` invalidates all outstanding ownership entries; software must
  coordinate it with traffic because late responses are then discarded.

## Integration Assumptions and Limits

- At the host-facing boundary, AW and W are presented and accepted in the same
  clock cycle. `wppp_hint_snoop` relies on that project contract: it qualifies
  on AWVALID and samples WDATA in that cycle; it does not independently pair
  AXI address and data channels.
- Production hint slots use the 16/42 format below. The explicit simulation
  compatibility mode alone retains 50-bit direct addresses and 14-bit counts.
- The translated PA guard uses
  `[cxl_start_pa, cxl_start_pa + csr_addr_ub)` and checks the complete page
  fragment with 65-bit arithmetic. `csr_addr_lb` remains unused.
- Read errors and malformed `rlast` are not surfaced.
- A successful write statistic means W was accepted, not that B was OKAY.
- The top-level AXI interface carries six AWUSER bits while the NCP module
  declares seven.
- Generated FIFO descriptors specify depth 256 and 8-bit `usedw`; RTL retains
  narrower debug occupancy signals from the earlier FIFO depths.

## Translation-Cache Hint Contract

The production 64-bit software hint record is:

```text
63          58 57                    42 41                       0
+--------------+------------------------+--------------------------+
| reserved = 0 | cacheline count [15:0] | virtual address VA[47:6] |
+--------------+------------------------+--------------------------+
```

- The address is a 64-byte-aligned, 48-bit userspace VA; hardware reconstructs
  it as `{hint[41:0], 6'b0}`. The upper six record bits are reserved and must be
  zero.
- A zero count marks an unused hint slot. Although the field is 16 bits, the
  first-version software contract limits a nonzero count to 128 cachelines.
- Translation uses 4 KiB pages and preserves VA `[11:0]`. A 128-cacheline hint
  can cover at most three pages, including a hint starting at the final
  cacheline of a page; each page fragment therefore receives a separate cache
  lookup.
- Push eligibility is checked only after translation. The range supplied by
  software is a PA range, and each translated page fragment is accepted only
  when its entire cacheline interval lies in that range. A rejected fragment
  is dropped before WPPP issue and counted independently; it does not reject
  other page fragments from the same original hint.
- Cache fill is independent of push eligibility. A completed translation is
  inserted even when its PA is outside the configured push range. The PA guard
  is applied to the translated result after lookup and before WPPP issue, not
  to the input VA or to cache admission.

## Cache, Miss, and Flush Behavior

- Geometry is four banks, 16,384 sets per bank, and eight 64-bit ways per set:
  524,288 cached 4 KiB translations, representing 2 GiB of virtual coverage.
- VA `[13:12]` selects the bank, VA `[27:14]` selects the set, and VA `[47:28]`
  is the 20-bit tag. Entries contain a 40-bit PPN for 52-bit PA reconstruction.
  Replacement is round-robin independently for every bank/set.
- Every absent lookup increments the miss counter. The first miss for a VPN
  allocates one of 256 MSHR entries and one 128-cycle timer-wheel slot. Further
  misses matching that in-flight VPN increment the coalesced counter. Every
  miss fragment is discarded; no requester is replayed.
- When the timer expires, exactly one mapping is inserted and the MSHR entry is
  released. A full hashed MSHR set and a timer-wheel slot collision are distinct
  capacity drops with distinct counters.
- `PA = VA - csr_wppp_translation_offset`. The offset must fit in 52 bits and
  be page aligned by software. Subtraction underflow is rejected and counted;
  no wrapped mapping is inserted.
- CSR flush drops queued or active pre-WPPP records, cancels MSHRs/timers, and
  sweeps 16,384 cache rows. Fragments already handed to an engine FIFO proceed.
  All statistics survive this flush and clear only at power-on reset.

## WPPP-Specific CSR Map

The existing 96-entry CSR file uses the formerly idle range 66 through 95.
CSR 67 is a write-one event implemented as a clock-domain-crossing toggle, not
a sticky reset level.

| Index | Meaning |
| ---: | --- |
| 66 | Translation offset, byte address (RW) |
| 67 | Bit 0: trigger full cache flush (write event) |
| 68 | Status: ready, flush busy/done, MSHR occupancy/high-water |
| 69–74 | Hit, miss, coalesced miss, unique allocation, insertion, PA/translation rejection |
| 75–80 | Invalid slot, decoded-FIFO drop, MSHR admission drop, timer-capacity drop, flush record drop, flush MSHR cancellation |
| 81–85 | Decoded/timer full cycles and episodes, packed MSHR occupancy/high-water |
| 86–88 | Hint-line, engine-0 FIFO, and engine-1 FIFO drops |
| 89–91 | Hint-line, engine-0 FIFO, and engine-1 FIFO full cycles |
| 92–94 | Hint-line, engine-0 FIFO, and engine-1 FIFO full episodes |
| 95 | Reserved |

The first version processes all page fragments of one hint to completion. A
future option is page-boundary time slicing: after completing one page
fragment, save the remaining VA, count, and engine selector as a continuation,
place it behind already queued hints, and later resume it. This bounds
head-of-line blocking for larger hints while preserving page-local lookup and
range checks. It is intentionally deferred because the initial 128-cacheline
limit already bounds one hint to three page lookups.

## Regression Compatibility and Coverage Gap

`wppp_integration_sim` deliberately instantiates `wppp_hint_snoop` with
`LEGACY_HINT_FORMAT=1` and `wppp_translation_stage` with
`LEGACY_DIRECT_MODE=1`. Its maintained cases still verify fake-CXL/fake-MC,
dual-engine WPPP, arbitration, backpressure, response ordering, and inactive
HPPB behavior using the historical direct-PA records. They do not demonstrate
translation-cache correctness.

New directed cache-mode cases are still required for cold miss and delayed
fill, later hit, same-VPN coalescing, all MSHR/timer capacity drops, one/two/
three-page splitting, PA-range rejection after both hit and fill, per-set RR
replacement, POR readiness, CSR flush cancellation, and coherent CSR snapshots.

## Legacy Source

`prefetch_dummy.sv`, `prefetch_fifo.sv`, `prefetch_hint_fifo.sv`,
`prefetch_one.sv`, `prefetch_read_write*.sv`, `wpprefetch_rw.sv`, and
`wpprefetch_rw_pipe.sv` are not in the active production hierarchy. Preserve
them unless a separate cleanup change proves they are no longer required by
another build configuration.

Behavioral changes to the active hierarchy require an update to this contract,
the relevant standalone or integration test, `BUG.md`, and `CHANGE.md`.
