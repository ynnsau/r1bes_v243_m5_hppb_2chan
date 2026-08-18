# Standalone WPPP Simulation

This suite isolates `wppprefetch_rw_pipeline_v2` and preserves the original
expected-pass cases and known-defect reproducers. End-to-end hint snooping,
page-table filtering, fake CXL/MC routing, and CPU-side sink checks live in the
separate [AXI integration suite](../wppp_integration_sim/README.md).

This harness verifies the production `wppprefetch_rw_pipeline_v2` hierarchy in
isolation. It is optimized for fast protocol/ownership feedback; full-project
integration remains the responsibility of Quartus quick elaboration and full
compile.

## Requirements

```bash
module load quartus/26.1
vsim -version
```

The current module supplies Questa FSE 2025.3.

## Commands

From the repository root:

```bash
make sim-smoke
make sim-focused
make sim-full
make sim-repro
```

Or run one case directly:

```bash
make -C wppp_sim compile
make -C wppp_sim sim-fast SIM_PLUSARGS=+RUN_SINGLE_HINT WORKFLOW_NOTIFY=0
```

Use `make -C wppp_sim list-sim-tiers` for the tier summary. Regression pings
are enabled by default; append `WORKFLOW_NOTIFY=0` for silent iteration.

## Expected-Pass Catalog

| Test | Tier | Purpose |
| --- | --- | --- |
| `RUN_SINGLE_HINT` | Smoke | Four-line hint, matching reads and NCP writes, payload/address scoreboard. |
| `RUN_OUT_OF_ORDER` | Smoke | Back-to-back reads returned in reverse order; verifies ID-to-address ownership. |
| `RUN_BACKPRESSURE` | Focused | Independent AR, AW, and W stalls; checks stable valid/payload and eventual progress. |
| `RUN_HINT_QUEUE` | Focused | Multiple queued hints expand in FIFO order without address/data loss. |
| `RUN_LUT_FLUSH` | Focused | Flush invalidates outstanding ownership and prevents stale response writeback. |
| `RUN_ID_WRAP` | Full | 1030 one-line requests cross the 10-bit ID wrap and verify safe reuse. |

## Expected-Fail Reproducers

| Test | Issue | Required classification |
| --- | --- | --- |
| `RUN_AR_LAST_STALL_REPRO` | `WPPP-AR-DEQUEUE-001` | `XFAIL` with the exact final-dequeue marker. |
| `RUN_RANGE_HEAD_BLOCK_REPRO` | `WPPP-RANGE-HOL-002` | `XFAIL` with the exact range-head marker. |

Expected-fail tests are never included in smoke/focused/full pass counts. An
`XPASS` means behavior changed and must be reviewed before the issue is closed
or the test is promoted.

## Behavioral IP Boundary

`rtl/behavioral_ip.sv` supplies simulation models for:

- `fifo_32w_73d`: 73-bit, depth-256, synchronous show-ahead hint FIFO;
- `fifo_128w_588d`: 588-bit, depth-256, synchronous show-ahead NCP FIFO;
- `w4096_d64`: dual-port storage with the read latency required by the active
  LUT/response pipeline.

The model deliberately matches active RTL port widths, including truncated
debug `usedw` signals. It does not prove that regenerated vendor IP has the
same port metadata, primitive mapping, reset behavior, or implementation
timing. Quartus elaboration is the integration gate for those properties.

The standalone top also does not instantiate AFU hint snooping,
`page_tbl_update`, the two-engine round-robin, the HPPB AXI arbiters, CDC, CSR,
or the CXL IP. It drives the v2 pipeline contract directly.

## Result Classification and Artifacts

Each expected-pass test requires a zero child status, its exact
`WPPP_TEST_PASS` marker, and no simulator/error marker. Passing make and vsim
logs are gzip-compressed by default. Failures retain plain logs and receive one
verbose rerun; a rerun-only success is `FLAKY` and fails the profile.

A run directory contains:

```text
plan.json
<test>.make.log[.gz]
<test>.vsim.log[.gz]
<test>.status
<test>.result.json
summary.json
```

Run directories are ignored and must be unique/nonempty. The default names
include a UTC timestamp. Duration history is kept under
`wppp_sim/logs/.duration_history.json` to start longer tests first.

## Maintained Status

On 2026-08-18, using Questa FSE 2025.3:

- focused profile: 5/5 PASS;
- full profile: 6/6 PASS;
- expected-fail profile: 2/2 XFAIL;
- simulator compilation: zero errors;
- known elaboration warning: 7-bit WPPP NCP AWUSER connects to a 6-bit
  `axi_ports.awuser` field (`WPPP-AWUSER-WIDTH-003`).

This snapshot describes the working tree at the time of workflow migration;
the machine-readable artifacts remain local and ignored.
