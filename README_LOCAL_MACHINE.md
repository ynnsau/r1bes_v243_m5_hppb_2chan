# Local Machine Setup

This runbook covers the current `/research` installation used by this checkout.
It contains no private credentials.

## Repository Paths

```text
/research/yans3/gitdoc/cmdp_hw/cmdp_hw_00
/research/yans3/gitdoc/cmdp_hw/cmdp_hw_00/hardware_test_design
/research/yans3/gitdoc/cmdp_hw/cmdp_hw_00/wppp_sim
/research/yans3/gitdoc/cmdp_hw/cmdp_hw_00/wppp_integration_sim
```

The workflow source used for migration was
`/research/yans3/r1bes_v243_remap`; it is not a runtime dependency.

## Simulation Environment

```bash
cd /research/yans3/gitdoc/cmdp_hw/cmdp_hw_00
module purge
module load quartus/26.1
vsim -version
make sim-smoke WORKFLOW_NOTIFY=0
make sim-integration-smoke WORKFLOW_NOTIFY=0
```

The module currently supplies Questa FSE 2025.3. The standalone harness uses
behavioral models for the two WPPP FIFOs and ID/address RAM, so no generated
ModelSim setup script is required. It still compiles the production WPPP RTL.
The separate integration harness reuses those models and adds a behavioral
page table, AXI-level fake CXL IP, device-side fake MC, and host CPU sinks.

## Quartus Environment

```bash
cd /research/yans3/gitdoc/cmdp_hw/cmdp_hw_00
module purge
module load quartus/25.3
quartus_sh --version
make quartus-preflight
make quartus-quick WORKFLOW_NOTIFY=0
```

The project-matched installation is Quartus Prime 25.3. Do not use 26.1 to
regenerate project IP unless that migration is separately requested and
reviewed.

This checkout currently lacks much of its generated synthesis collateral.
Check it without writing files:

```bash
make quartus-ip-check
make quartus-ip-plan
```

As of 2026-08-18 the check reports seven missing generated QIPs, 36 missing
files referenced by existing QIPs, and 27 affected descriptors. The plan prints
one project-scoped `qsys-generate` batch command. Do not blindly copy the
generated trees from `/research/yans3/r1bes_v243_remap`: its WPPP FIFO output
was generated for the older 32/128-entry settings, while this checkout's `.ip`
descriptors specify depth 256.

IP regeneration is intentionally not automatic. It may create gigabytes of
collateral and update partially checked-in generated metadata. Inspect
`git status --short` before and after, and run it only from
`hardware_test_design` with Quartus 25.3.

Quartus outputs live under `hardware_test_design/output_files` and other
ignored project directories. Workflow logs live under root `logs/`. The runner
will not reuse a nonempty run directory.

## Notification Setup

Pushover uses private environment variables:

```bash
export PUSHOVER_APP_TOKEN='<private app token>'
export PUSHOVER_USER_KEY='<private user key>'
export WORKFLOW_PING_TRANSPORT=pushover
```

SMTP is also supported:

```bash
export WORKFLOW_PING_TRANSPORT=email
export SMTP_HOST='<smtp host>'
export SMTP_PORT=587
export SMTP_USER='<smtp user>'
export SMTP_PASS='<private password>'
export WORKFLOW_EMAIL_TO='yans3@illinois.edu'
```

Test formatting without sending:

```bash
PUSHOVER_APP_TOKEN=dummy PUSHOVER_USER_KEY=dummy \
  WORKFLOW_PING_TRANSPORT=pushover \
  python3 tools/send_workflow_ping.py \
    --event checkpoint --name "wppp local setup" --status READY \
    --body "dry-run only" --dry-run
```

Dry-run output redacts Pushover credentials. Delivery failures are warnings by
default so notification infrastructure cannot change a valid hardware result.
Use `--strict` only when testing the notification channel itself.

## Useful Checks

```bash
make help
make test-tools
git status --short
git diff --check
```

If a command reports that Questa or Quartus is absent, load the corresponding
module in that same shell. Avoid loading both versions at once.
