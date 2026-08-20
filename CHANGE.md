# Change Log

Reverse-chronological outcomes for WPPP source, verification, and workflow
changes. Open issue state belongs in `BUG.md`; detailed test contracts belong
in the relevant simulation README.

## 2026-08-20

Issue: replace inferred WPPP ATC storage with generated IP

1. Replaced each cache bank's eight inferred 64-bit way memories with one
   generated 512-bit by 16,384-entry dual-port RAM. Byte enables update one
   way on insertion or all ways during the row-swept flush.
2. Aligned lookup tag and valid through two edges to match the RAM's registered
   read address and output. Mixed-port writes retain `OLD_DATA` behavior.
3. Replaced the handmade 81-bit decoded-hint queue with the generated 32-entry
   registered show-ahead FIFO and its synchronous clear. A full FIFO drops a
   simultaneous incoming hint even when a pop occurs, as permitted by the
   design contract, and the existing drop counter records it.
4. Derived exact 0-through-32 flush occupancy from `{full, usedw[4:0]}` without
   adding a second software-visible counter.
5. Added a production-format fake-CXL/fake-MC ATC integration top and directed
   cold-miss, 128-cycle fill, repeated-hit, device-read, and CPU-write case.
   Simulation compiles the generated wrappers/cores and loads their Quartus
   26.1 `altera_mf_ver` and `altera_lnsim_ver` primitive libraries.

## 2026-08-19

Issue: first WPPP translation-cache implementation

1. Replaced the production WPPP connection to the HPPB residency bitmap with a
   dedicated translation stage. HPPB remains an independent AXI client and no
   longer supplies WPPP admission state.
2. Added the 64-bit `{reserved[5:0], count[15:0], VA[47:6]}` decoder. Count zero
   is the unused-slot marker, software is limited to 128 cachelines, and the
   selector continues to advance through all eight physical slots.
3. Added an inferred-RAM translation cache with four banks, 16K sets per bank,
   eight ways, 40-bit PPNs, per-set round-robin replacement, and a row-swept
   POR/CSR flush that preserves block-RAM inference.
4. Added 4 KiB page splitting, fixed `PA = VA - offset` translation, full-width
   post-translation PA range checking, and engine-ready holding. Cache fills
   remain independent of PA push eligibility.
5. Added a 32-set/eight-way coalescing MSHR and a 128-cycle timing wheel. Every
   miss is counted and dropped, matching misses share one service/insertion,
   and MSHR-set and timer-capacity failures have separate counters.
6. Added CSR 66–95 controls/status/statistics. Twenty-six 64-bit statistics are
   transferred coherently from 400 MHz to 125 MHz every 64 fast cycles; cache
   flush never clears counters.
7. Extended the existing WPPP engine hint FIFO from `{14,50}` to `{16,52}` and
   exposed FIFO admission, drop, full-cycle, and full-episode information.
8. Kept the existing integration tests honest by selecting explicit legacy
   decoder/direct-stage parameters in their wrapper. They continue to cover
   the prior fake-CXL/fake-MC direct-PA path and do not claim cache coverage.
9. Questa 2025.3 compiled the final 13-source standalone and 19-source
   integration file lists with zero errors, and the default new-mode
   translation stage elaborated with zero errors.
10. Re-ran all maintained legacy/direct-path cases after integration: seven
    standalone cases, five fake-CXL/fake-MC functional cases, and four
    integration stress cases passed. The range-head known-defect reproducer
    retained its expected `XFAIL` classification. Evidence is under
    `wppp_sim/logs/full_20260819T180931Z`,
    `wppp_integration_sim/logs/full_20260819T180941Z`,
    `wppp_integration_sim/logs/stress_20260819T180951Z`, and
    `wppp_sim/logs/repro_20260819T181004Z`.
    Functional cache-mode directed tests and Quartus compilation remain for
    the next verification handoff.
11. Review closed a same-set fill/lookup hazard by holding a lookup while an
    insertion is entering or occupying the cache-bank write pipeline, avoiding
    a stale miss and redundant translation allocation. CSR 67 now also reads
    as zero after its write-trigger event instead of retaining the written bit.
    Both simulation trees recompiled and their smoke tiers passed afterward.

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
10. Added integration cases for DB-read backpressure, independently stalled NCP
    AW/W with BVALID held low through the transfer, reverse-order DB responses
    on both engines, and sparse multi-line hint sequencing. All changes are
    confined to the testbench, workflow, and documentation; production RTL is
    unchanged.
11. Ran the DB-backpressure case first and stopped on its deterministic failure,
    as requested. Three reads handshook; the fourth request (`id=3`,
    `addr=0x00000061800800c0`) was visible before the stall and disappeared one
    clock later while ARREADY remained low. The integration repro classified
    this as `XFAIL`; the other three new cases remain unexecuted in this run.
12. Added a page-filter contract describing bitmap geometry, synchronous lookup
    latency, update-time hint suppression, address-alias and cross-page
    assumptions, and the unverified upper-half shift expression.
13. Completed the remaining integration stress cases: NCP backpressure,
    reverse-order DB responses, and sparse multi-line hint sequencing all
    passed with zero checker errors.
14. Fixed `WPPP-AR-DEQUEUE-001` in production `wppp_hb_req`. FIFO heads now
    transfer into a stable active-hint context, final retirement is tied to the
    AR handshake, and a pending-AR hold preserves VALID/ID/address when READY
    is low even if prefetch enable subsequently drops.
15. Promoted the standalone one-line/final-AR and full-integration DB
    backpressure checks from expected-fail characterization to maintained
    expected-pass regressions. No new BRAM or FIFO IP was required.
16. Verified the fix with Questa FSE 2025.3: all seven standalone full-tier
    cases, all five integration full-tier cases, and all four integration
    stress cases passed. The separate range-head reproducer remained `XFAIL`,
    and all 16 workflow-tool unit tests passed.

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
