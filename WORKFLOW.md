# WPPP Development Workflow

This is the authoritative procedure for WPPP investigation, RTL changes,
simulation, Quartus compilation, evidence, documentation, and user pings.
Specific run outcomes belong in the relevant simulation README or `CHANGE.md`,
not here.

## 1. Core Rules

1. Inspect `git status --short` before touching source. Preserve unrelated user
   changes and generated collateral.
2. Identify the active hierarchy before editing. The production WPPP top is
   `wppprefetch_rw_pipeline_v2`; similarly named older modules are not active.
3. Reproduce a suspected defect before changing RTL when a bounded simulation
   can express it.
4. Keep expected-pass tests and known-defect reproducers in separate runs.
   A known defect is `XFAIL`, never a passing functional test.
5. Never use an old simulator transcript or Quartus report as new evidence.
   The runners refuse nonempty log directories and the compile runner requires
   reports changed by the current invocation.
6. A process exit code alone is not a pass. Simulation requires its exact
   completion marker and no error markers. Quartus requires its fresh
   mode-specific reports and no error markers.
7. Notifications are best-effort reporting. A notification outage cannot turn
   a valid hardware result into a failure or hide a failing hardware result.

## 2. Establish a Baseline

```bash
git status --short
git log -5 --oneline
module load quartus/26.1
make test-tools
make sim-smoke WORKFLOW_NOTIFY=0
```

For a protocol or integration change, also run `sim-focused`. Before declaring
the complete standalone WPPP model healthy, run `sim-full` and `sim-repro`.
Before declaring the hint-to-CPU AXI path healthy, run
`sim-integration-full` as well.

Record:

- source commit and tracked worktree state;
- exact command and tool version;
- result JSON path;
- first meaningful failure marker, if any;
- whether vendor IP or behavioral simulation models were used.

The regression runner writes the source and invocation to `plan.json`, one
result per test, and an aggregate `summary.json`.

## 3. Simulation Loop

Load Questa through the Quartus 26.1 module:

```bash
module load quartus/26.1
```

Available tiers:

```bash
make sim-smoke       # basic copy plus out-of-order response ownership
make sim-focused     # smoke plus backpressure, hint ordering, and LUT flush
make sim-full        # focused plus 10-bit ID-wrap stress
make sim-repro       # known defects, expected to classify XFAIL
make sim-integration-smoke    # host pass-through plus one full hint
make sim-integration-focused  # dual-engine batch and concurrent host traffic
make sim-integration-full     # focused plus inactive-HPPB isolation
```

Run one case while developing:

```bash
make -C wppp_sim sim SIM_PLUSARGS=+RUN_SINGLE_HINT WORKFLOW_NOTIFY=0
make -C wppp_sim sim-fast SIM_PLUSARGS=+RUN_SINGLE_HINT WORKFLOW_NOTIFY=0
make -C wppp_integration_sim sim \
  SIM_PLUSARGS=+RUN_INT_SINGLE_HINT WORKFLOW_NOTIFY=0
```

`sim-fast` assumes the `work` library was already compiled. Use plain `sim`
after RTL, package, file-list, or behavioral-IP changes.

Expected-pass classification requires all three conditions:

- child exit status is zero;
- transcript contains `WPPP_TEST_PASS: <test>`;
- transcript contains no `WPPP_CHECK_ERROR`, `WPPP_TEST_FAIL`,
  `WPPP_INT_CHECK_ERROR`, `WPPP_INT_TEST_FAIL`, Questa `** Error`/`** Fatal`,
  or nonzero `Errors:` marker.

Passing logs are gzip-compressed by default. A failing test is rerun once with
a separate verbose name. If only the rerun passes it is `FLAKY`, which still
fails the aggregate run. Preserve the first-failure evidence.

Known-defect reproducers require their exact `WPPP_REPRODUCED:` marker. The
valid states are:

- `XFAIL`: defect reproduced as expected;
- `XPASS`: the functional test unexpectedly passed; investigate whether RTL
  fixed the issue and then promote the test deliberately;
- `FAIL`: neither the expected defect marker nor a valid pass appeared.

## 4. First-Mismatch Discipline

On a failure:

1. Open the per-test `*.result.json` and the named transcript.
2. Find the earliest protocol or scoreboard mismatch, not the final timeout.
3. Trace ownership through hint FIFO, AR handshake, LUT ID, R response, NCP
   FIFO, AW handshake, and W handshake.
4. Decide whether the mismatch is production RTL, the behavioral IP boundary,
   the testbench, or an undocumented platform assumption.
5. If changing RTL, add or strengthen a directed test before the fix whenever
   practical.
6. Re-run the smallest test, then its tier, then `sim-full` for a shared-stage
   or ownership change.

Do not change production RTL merely to accommodate a behavioral-model timing
mistake. Compare generated IP latency and show-ahead behavior first.

## 5. Quartus Quick Elaboration

Quartus project work remains on version 25.3:

```bash
module purge
module load quartus/25.3
make quartus-preflight
make quartus-quick
```

`quartus-preflight` prints both compile plans and then checks every QSF IP/QIP
assignment plus the generated files referenced by each QIP. A fresh or cleaned
checkout may fail here before RTL elaboration. Inspect and plan recovery with:

```bash
make quartus-ip-check
make quartus-ip-plan
```

The current baseline needs synthesis regeneration for 27 descriptors. The plan
is intentionally read-only: generation can populate or update large IP trees,
so review its scoped `qsys-generate` command and preserve local collateral
before executing it from `hardware_test_design`.

The quick runner executes:

```text
quartus_syn --read_settings_files=on --write_settings_files=off \
  cxltyp2_ed -c cxltyp2_ed --quick_elab
```

A pass requires:

- zero process status;
- no Quartus error marker;
- a fresh `output_files/cxltyp2_ed.syn.quick_elab.rpt` changed by this run.

Quick elaboration checks integration and elaboration. It does not establish
fit, timing, assembly, or bitstream readiness.

The 2026-08-18 migration validation reached this gate and classified
`compile_fail`: seven generated QIPs and 36 QIP-referenced synthesis files were
missing, and the QSF also failed to resolve the AFU-banking
`cxl_type2_defines.svh.iv`/`mc_axi_if_pkg` context. These are baseline project
collateral/file-list prerequisites, not WPPP simulation failures. Do not claim
a quick-elaboration pass until both classes are resolved and a fresh report is
classified `pass`.

## 6. Full Compile and Timing Gate

Run the full flow when the work requires implementation/timing evidence:

```bash
module purge
module load quartus/25.3
make quartus-full
```

The runner executes `quartus_sh --flow compile cxltyp2_ed -c cxltyp2_ed` and
requires fresh flow and STA summaries. The inherited project acceptance gate
is:

```text
coreclkout_hip setup WNS >= -0.900 ns
```

Override it only for an explicitly scoped experiment:

```bash
make quartus-full MIN_WNS=-0.800
```

A full pass requires a successful flow report, no Quartus error marker, a
parseable `coreclkout_hip` setup result, and WNS at or above the selected gate.
A clean Quartus exit with worse WNS is `timing_fail`, not pass. The runner also
records the matching TNS for context.

`result.json` captures the command, source state before and after, tool version,
report paths, flow status, timing, and reasons. Review any new tracked changes
after Quartus because this legacy project contains tracked Quartus log files.

## 7. Notifications

Tiered regression, reproducer, and Quartus targets send one aggregate start and
one aggregate finish/error ping when `WORKFLOW_NOTIFY=1` (the default).
Per-test pings are intentionally avoided.

Priority policy:

- mid: workflow start, successful regression, successful compile;
- high: simulation error, compile error, timing-gate failure, tool error.

Disable pings for validation or rapid local iteration:

```bash
make sim-focused WORKFLOW_NOTIFY=0
make quartus-quick WORKFLOW_NOTIFY=0
```

For any arbitrary long command, use:

```bash
tools/workflow_notify_run.sh --kind command --name "description" -- command args
```

The wrapper preserves the command's exit status. Delivery is non-strict by
default; see `README_LOCAL_MACHINE.md` and `tools/README.md` for transports and
dry-run setup.

## 8. Evidence and Documentation Gate

Before handing off a behavioral change:

```bash
make test-tools
module load quartus/26.1
make sim-full WORKFLOW_NOTIFY=0
make sim-repro WORKFLOW_NOTIFY=0
make sim-integration-full WORKFLOW_NOTIFY=0
git diff --check
git status --short
```

Then update, as applicable:

- prefetch `README.md` for stable module behavior or assumptions;
- `wppp_sim/README.md` for test intent or maintained-suite status;
- `BUG.md` for issue state;
- `CHANGE.md` for the completed outcome;
- `PROJECT.md` for implementation handoff detail;
- `WORKFLOW.md` only when procedure or acceptance gates changed.

Do not claim full compile, timing closure, hardware validation, or notification
delivery unless that exact action was performed and its evidence was inspected.

## 9. Stop and Escalate

Stop and ask for direction before:

- changing the hint wire format or host software contract;
- choosing whether an out-of-range hint should drop, retry, or block;
- changing AXI user encodings without the platform definition;
- regenerating checked-in IP with a different Quartus version;
- weakening the timing gate;
- publishing or programming a bitstream;
- deleting generated collateral or overwriting unrelated worktree changes.
