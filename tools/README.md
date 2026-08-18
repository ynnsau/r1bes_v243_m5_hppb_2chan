# Workflow Tools

These tools provide deterministic run classification and best-effort user
notifications. They use only the Python standard library.

## Simulation Regression Runner

`wppp_sim/tools/run_regression.py` is shared by the standalone and AXI-level
integration Makefiles. It compiles once, schedules test processes longest-first
across `JOBS`, requires an exact per-test completion marker, recognizes both
`WPPP_*` and `WPPP_INT_*` error markers, reruns failures once with verbose
artifacts, and records JSON plans/results/summaries. Each suite owns its test
list and log directory; the integration suite does not replace the standalone
cases or expected-fail runner. Its `--suite-name wppp-integration` label also
keeps aggregate start/finish/error pings distinct from standalone runs.

## Quartus Runner

`run_quartus.py` supports two modes:

```bash
module load quartus/25.3

python3 tools/run_quartus.py \
  --mode quick-elab \
  --project-dir hardware_test_design \
  --log-dir logs/quick_example \
  --notify 0

python3 tools/run_quartus.py \
  --mode full \
  --project-dir hardware_test_design \
  --min-wns -0.900 \
  --log-dir logs/full_example \
  --notify 0
```

Use `--dry-run` to resolve and print the plan without creating the log
directory. Live runs refuse a nonempty directory. Quick mode requires a fresh
`cxltyp2_ed.syn.quick_elab.rpt`; full mode requires fresh flow and STA summaries
and applies the selected `coreclkout_hip` timing gate.

The runner writes `plan.json`, a streamed `quartus.log`, and `result.json`.
Statuses are `pass`, `compile_fail`, or `timing_fail`; configuration/tool
preflight errors return status code 2 before a result can be classified.

## IP Collateral Check

Before either project build, inspect generated QIP/synthesis readiness:

```bash
make quartus-ip-check
make quartus-ip-plan
```

`check_quartus_ip.py` resolves the project's IP/QSYS/QIP assignments, derives
the expected generated QIP for descriptor inputs, and checks every file joined
through `$::quartus(qip_path)` in existing QIPs. Check mode returns nonzero for
incomplete collateral. Plan mode is read-only and prints one shell-quoted,
project-scoped Quartus 25.3 `qsys-generate` command for affected descriptors.

The Makefile makes `quartus-quick` and `quartus-full` depend on this check, so a
known-incomplete checkout fails before spending time in Quartus.

## Notification Helper

`send_workflow_ping.py` supports Pushover, SMTP, and local sendmail. Transport
selection is `auto` by default: configured Pushover credentials win, otherwise
email is attempted. Use `WORKFLOW_PING_TRANSPORT=all` to request both.

Common events include `regression-start`, `regression-finish`, `test-error`,
`compile-start`, `compile-finish`, `compile-error`, and `timing-error`.

```bash
python3 tools/send_workflow_ping.py \
  --event checkpoint \
  --name "wppp manual checkpoint" \
  --status PASS \
  --body "Focused simulation completed" \
  --dry-run
```

Credentials are read only from arguments or environment and are redacted in a
Pushover dry run. Delivery is best-effort unless `--strict` is supplied.

## Command Wrapper

```bash
tools/workflow_notify_run.sh \
  --kind compile \
  --name "manual experiment" \
  -- command args
```

The wrapper emits aggregate start and finish/error events and always returns
the wrapped command's status. Set `WORKFLOW_NOTIFY=0` to run it silently.

## Unit Tests

```bash
make test-tools
```

The tests cover report/timing parsing, fresh-run classification with fake
Quartus tools, timing-gate failure, notification redaction, wrapper status
preservation, simulator result classification, scheduling, and dry-run
non-mutation.
