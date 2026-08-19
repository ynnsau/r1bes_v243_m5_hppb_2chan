# Known WPPP Bugs and Contract Risks

Last updated: 2026-08-18 local time.

This is the issue/status index. Stable behavior belongs in the prefetch module
contract, test definitions belong in the relevant simulation README, and
completed outcomes belong in `CHANGE.md`.

## Issue Index

| Issue | State | Severity | Evidence |
| --- | --- | --- | --- |
| [`WPPP-AR-DEQUEUE-001`](#wppp-ar-dequeue-001-final-hint-can-dequeue-before-ar-handshake) | Fixed; expected-pass regression | High data/protocol | `RUN_AR_LAST_STALL`; `RUN_INT_DB_BACKPRESSURE` |
| [`WPPP-RANGE-HOL-002`](#wppp-range-hol-002-out-of-range-head-blocks-the-hint-queue) | Open; deterministic XFAIL | High liveness | `RUN_RANGE_HEAD_BLOCK_REPRO` |
| [`WPPP-AWUSER-WIDTH-003`](#wppp-awuser-width-003-ncp-awuser-is-truncated-at-the-interface) | Open integration cleanup | Low | Questa elaboration warning |
| [`WPPP-HINT-HANDSHAKE-004`](#wppp-hint-handshake-004-hint-snoop-assumes-paired-aw-and-w) | Accepted project contract | Medium if violated | Integration host driver and README contract |
| [`WPPP-FIFO-METADATA-005`](#wppp-fifo-metadata-005-active-rtl-retains-old-usedw-widths) | Open tooling cleanup | Low | `.ip` descriptor/RTL inspection |
| [`WPPP-V2-SURFACE-006`](#wppp-v2-surface-006-legacy-control-and-filter-surface-is-inactive) | Documented limitation | Low | RTL integration inspection |
| [`WPPP-BUILD-COLLATERAL-007`](#wppp-build-collateral-007-quartus-project-is-missing-generated-ip-and-source-context) | Open build prerequisite | Blocks project compile | Quartus 25.3 quick-elab result |

## WPPP-AR-DEQUEUE-001: Final Hint Can Dequeue Before AR Handshake

Status: fixed on 2026-08-18; promoted to standalone and AXI-level integration
expected-pass regressions

Severity: high; a cacheline request can be silently lost under AR backpressure

The former implementation asserted `dequeue_valid` whenever
`cl_counter + 1 == num_cl`, independent of `arvalid && arready`. A one-line
hint could therefore disappear before becoming eligible, and a multi-line
hint lost its final request whenever that AR was backpressured.

The fix transfers a FIFO head exactly once into an active-hint register. The
FIFO may then advance, but the active base/count/index remain stable until the
final AR handshake. A fall-through pending-AR register captures the payload
when READY is low and holds VALID, ID, and address independently of subsequent
enable, abort, range, or LUT-gating changes. Count, ID, LUT insertion, and final
active-hint retirement are all qualified by the same AR handshake.

Verify with:

```bash
module load quartus/26.1
make -C wppp_sim sim-focused WORKFLOW_NOTIFY=0
make -C wppp_integration_sim sim-stress WORKFLOW_NOTIFY=0
```

Required pass markers include:

```text
WPPP_TEST_PASS: RUN_AR_LAST_STALL
WPPP_TEST_PASS: RUN_INT_DB_BACKPRESSURE
```

## WPPP-RANGE-HOL-002: Out-of-Range Head Blocks the Hint Queue

Status: open; reproduced by the standalone expected-fail suite

Severity: high; one bad multi-line hint can stop all later prefetch work

The head hint is issued only when its address is inside the registered range.
There is no invalid-head drop, rejection response, or skip path. For a
multi-line out-of-range hint the cacheline counter remains zero and the entry
never dequeues, so valid hints behind it cannot reach the head.

The correct policy is a software/RTL contract choice: reject/drop with
observability, retain until bounds change, or add a recovery command. The
`WPPP-AR-DEQUEUE-001` fix intentionally preserves this behavior.

Expected marker:

```text
WPPP_REPRODUCED: out-of-range head hint blocks following valid hint
```

## WPPP-AWUSER-WIDTH-003: NCP AWUSER Is Truncated at the Interface

Status: open integration cleanup

Severity: low for the current constant; the intended NCP encoding should still
be confirmed at the CXL AXI boundary

`wppp_ncp_pipe` declares a 7-bit AWUSER and drives `7'b0100010`, while
`axi_ports.awuser` in `common/include/types.sv` is six bits. Questa warns about
the connection at elaboration and truncates the module output to the interface
width. The truncated seventh bit is zero in `7'b0100010`, so the current value
is preserved. Confirm the platform encoding before changing either side;
several other design blocks use the six-bit interface.

## WPPP-HINT-HANDSHAKE-004: Hint Snoop Assumes Paired AW and W

Status: accepted project integration contract; exercised by the AXI-level
integration harness

Severity: medium

`wppp_hint_snoop`, instantiated by `afu_top.sv`, recognizes the hint write with
channel-0 AWVALID/address and captures WDATA in that cycle without independently
pairing the AXI write channels. The project contract is now explicit: AW and W
for a hint-page write are presented and accepted in the same clock cycle. The
integration host driver obeys this rule and reports divergent AWREADY/WREADY
while the paired request is active.

Under that contract this is not classified as an RTL defect. A future source
that permits independently timed hint AW/W handshakes must first add address/
data pairing to the snoop or an adapter; merely relaxing the test driver would
make hint data association ambiguous.

## WPPP-FIFO-METADATA-005: Active RTL Retains Old USEDW Widths

Status: open tooling cleanup

Severity: low for current function; occupancy is debug-only

Both WPPP FIFO `.ip` files now specify depth 256 and an 8-bit `usedw` port.
`wppp_hb_req` retains a 5-bit signal from the former 32-entry hint FIFO, and
`wppp_ncp_pipe` retains a 7-bit signal from the former 128-entry response FIFO.
Full/empty drive functional flow control, so truncation currently affects only
debug visibility. Regenerated IP should be elaborated before adjusting widths.

## WPPP-V2-SURFACE-006: Legacy Control and Filter Surface Is Inactive

Status: documented limitation

Severity: low unless a consumer assumes the named ports are implemented

The v2 wrapper bypasses `wppp_filter_check`, ties abort statistics to zero,
and leaves several state/current-address/filter/next-address outputs unused or
undriven. `addr_seen`, response status fields, and CSR AXI-user inputs do not
control the active data path. Remove or implement these only in a separately
reviewed interface cleanup.

## WPPP-BUILD-COLLATERAL-007: Quartus Project Is Missing Generated IP and Source Context

Status: open baseline build prerequisite

Severity: blocks project quick elaboration and full compile; standalone WPPP
simulation is unaffected

A real Quartus 25.3 quick-elaboration attempt on 2026-08-18 returned status 3
and was correctly classified `compile_fail`. The project is missing seven
generated QIP files and 36 synthesis/constraint files named by existing QIPs.
The affected set spans 27 descriptors, including the CXL tile, both active WPPP
FIFOs, the ID/address RAM, and the HPPB page table.

The same run also reported that AFU-banking sources could not resolve
`cxl_type2_defines.svh.iv` and `mc_axi_if_pkg`. The files exist in the banking
header directory, but the current QSF does not establish their required
include/package compilation context.

Use `make quartus-ip-check` for the read-only inventory and
`make quartus-ip-plan` for the scoped Quartus 25.3 regeneration command. Do not
reuse the reference repository's stale WPPP FIFO output: its generated depths
do not match this branch's depth-256 descriptors. After regeneration, rerun
quick elaboration to expose and fix any remaining QSF file-list issue before a
full compile.
