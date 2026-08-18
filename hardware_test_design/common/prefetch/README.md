# WPPP Prefetch Module Contract

This directory contains several generations of prefetch RTL. The production
top currently uses only the v2 WPPP pipeline and its four active stages.

## Active Hierarchy

```text
wppp_hint_snoop                 (AFU-level hint-page write observer)
page_tbl_update                 (HPPB residency filter, outside this directory)
  |
  +-- alternating nonzero hints to two instances of:
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
hint snoop and page-table filter feed alternating hints to those engines,
which share the two outgoing AXI channels with HPPB through `axi_arbiter`.

## Module Responsibilities

- `wpprefetch_rw_pipe_v2.sv`: active wrapper. Connects request, ownership,
  response, and NCP stages. The filter is bypassed and `NCP_PIPE_ON` is one.
- `wppp_hint_snoop.sv`: AFU integration block extracted from `afu_top.sv`.
  A write in the configured 4 KiB hint page captures one 512-bit line and
  emits its eight packed 64-bit hints on consecutive cycles, alternating the
  engine selection.
- `wppp_hb_req.sv`: accepts `{count,address}` hints and issues one device-biased
  64-byte read per cacheline. It advances its ID and count only on AR
  handshake, except for the known final-entry dequeue defect.
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
- Hint addresses use only 50 bits and counts use only 14 bits.
- The accepted range is `[start_address_i, start_address_i + address_upper_i)`;
  `address_lower_i` is presently unused.
- Read errors and malformed `rlast` are not surfaced.
- A successful write statistic means W was accepted, not that B was OKAY.
- The top-level AXI interface carries six AWUSER bits while the NCP module
  declares seven.
- Generated FIFO descriptors specify depth 256 and 8-bit `usedw`; RTL retains
  narrower debug occupancy signals from the earlier FIFO depths.

## Legacy Source

`prefetch_dummy.sv`, `prefetch_fifo.sv`, `prefetch_hint_fifo.sv`,
`prefetch_one.sv`, `prefetch_read_write*.sv`, `wpprefetch_rw.sv`, and
`wpprefetch_rw_pipe.sv` are not in the active production hierarchy. Preserve
them unless a separate cleanup change proves they are no longer required by
another build configuration.

Behavioral changes to the active hierarchy require an update to this contract,
the relevant standalone or integration test, `BUG.md`, and `CHANGE.md`.
