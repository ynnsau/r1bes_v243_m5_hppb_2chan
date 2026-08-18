# Change Log

Reverse-chronological outcomes for WPPP source, verification, and workflow
changes. Open issue state belongs in `BUG.md`; detailed test contracts belong
in the relevant simulation README.

## 2026-08-18

Issue: AXI-level fake CXL IP / fake MC WPPP integration simulation

1. Added `wppp_integration_sim` as a separate suite, preserving every existing
   standalone expected-pass case and known-defect reproducer.
2. Extracted the existing AFU hint-page observer into the reusable production
   `wppp_hint_snoop` module, retained its behavior in `afu_top`, and added the
   new source to the Quartus project file list.
3. Wrapped the production hint snoop, HPPB page-table filter, both v2 WPPP
   engines, and both final AXI arbiters at the AXI boundary. Full CXL protocol,
   CSR, and active-HPPB behavior remain intentionally outside the wrapper.
4. Added an AXI-level fake CXL IP that routes WPPP device-biased reads to a
   shared fake device MC and terminates NCP writes in two host/CPU-side sinks.
   Ordinary host memory traffic passes through the same wrapper and fake MC.
5. Tied HPPB table updates and request ports inactive, reset its previously
   uninitialized `hppb_tbl_update_reg`, and added continuous failure checks for
   any HPPB AXI activity during WPPP tests.
6. Documented the project contract that hint AW and W are presented and
   accepted synchronously; the integration host driver enforces paired traffic
   and checks that its ready signals do not diverge.
7. Added smoke, focused, and full parallel integration profiles with the same
   JSON evidence, compressed logs, verbose failure rerun, and aggregate user
   pings as the standalone workflow.
8. Validated all five integration cases with Questa FSE 2025.3: host
   pass-through, a four-line hint, an eight-hint/two-engine 16-line batch,
   concurrent host and WPPP traffic, and inactive-HPPB isolation all passed.
9. Kept `WPPP-AR-DEQUEUE-001` open and its standalone XFAIL intact. The
   integration batch uses two-line entries so an expected-pass workflow does
   not conceal or redefine the known one-line/final-AR defect.

Issue: WPPP workflow migration and baseline characterization

Source baseline: `5616643` (`mig_merged_26`)

Implementation commit: recorded by the enclosing commit

1. Documented the active two-engine WPPP hint/read/LUT/NCP path, its
   integration with AFU hint snooping and HPPB page-table filtering, and the
   distinction between active v2 modules and retained legacy implementations.
2. Added a standalone Questa harness using production WPPP RTL plus bounded
   behavioral models for the two generated FIFOs and ID/address RAM.
3. Added smoke, focused, and full expected-pass profiles with JSON plans,
   per-test results, aggregate summaries, passing-log compression, duration
   history, and one verbose failure rerun.
4. Added six maintained expected-pass tests covering the basic copy path,
   out-of-order responses, read/write backpressure, queued hints, LUT flush,
   and 10-bit ID wrap.
5. Added separately classified expected-fail reproducers for
   `WPPP-AR-DEQUEUE-001` and `WPPP-RANGE-HOL-002`.
6. Added a local single-project Quartus runner. Quick elaboration requires a
   fresh synthesis report; full compilation requires fresh flow/STA reports
   and enforces `coreclkout_hip` setup WNS of at least `-0.900 ns` by default.
7. Added best-effort aggregate workflow pings through Pushover, SMTP, or local
   sendmail, plus a status-preserving command wrapper. No credential was added
   to the repository.
8. Migrated the reference repository's documentation ownership style into a
   stable overview, engineering handoff, procedural workflow, local runbook,
   issue index, change log, simulation catalog, and module contract.
9. Added a read-only Quartus IP collateral checker and generation planner. It
   resolves all QSF IP/QSYS/QIP assignments, follows generated QIP file
   references, and prevents quick/full Make targets from starting with known
   missing collateral.
10. Local Questa 2025.3 validation passed all six expected-pass tests; both
   known-defect cases classified `XFAIL`. Workflow unit tests also passed.
11. A real Quartus 25.3 quick elaboration was attempted and correctly
   classified `compile_fail` (exit 3): seven generated QIPs, 36 QIP-referenced
   synthesis/constraint files, and AFU-banking include/package context are
   absent from the current project state. No tracked file changed during the
   attempt. Full compile was not run, and this entry does not claim Quartus
   elaboration or timing success.
