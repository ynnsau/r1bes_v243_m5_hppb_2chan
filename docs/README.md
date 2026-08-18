# Documentation Map

This page defines where project facts belong. Use it before adding a new note
so architecture, issue state, run evidence, and procedure do not become
competing sources of truth.

## Start Here

- [`../README.md`](../README.md): stable project overview and primary commands.
- [`../PROJECT.md`](../PROJECT.md): dense WPPP implementation handoff and
  integration reference.
- [`../WORKFLOW.md`](../WORKFLOW.md): simulation, compile, timing, notification,
  and evidence procedure.
- [`../README_LOCAL_MACHINE.md`](../README_LOCAL_MACHINE.md): local paths,
  module versions, and notification setup.
- [`../BUG.md`](../BUG.md): concise issue/status index.
- [`../CHANGE.md`](../CHANGE.md): reverse-chronological completed outcomes.
- [`../wppp_sim/README.md`](../wppp_sim/README.md): test catalog, commands,
  classification rules, and validation snapshots.
- [`../wppp_integration_sim/README.md`](../wppp_integration_sim/README.md):
  AXI integration boundary, fake CXL/MC responsibilities, tests, and planned
  extensions.
- [`../hardware_test_design/common/prefetch/README.md`](../hardware_test_design/common/prefetch/README.md):
  stable WPPP module contracts, assumptions, and active-versus-legacy map.
- [`../tools/README.md`](../tools/README.md): deterministic compile and ping
  tooling interfaces.

## Document Ownership

| Document | Authoritative for | Do not use it as |
| --- | --- | --- |
| Root `README.md` | Stable architecture and entry points | A live run log |
| `PROJECT.md` | Engineering handoff and implementation detail | Issue chronology |
| `WORKFLOW.md` | Required steps and acceptance gates | Proof a specific run passed |
| `README_LOCAL_MACHINE.md` | Workstation setup and private environment variables | Shared credentials |
| `BUG.md` | Issue ID, severity, state, and reproducer | A full RTL specification |
| `CHANGE.md` | Completed source/tool/test outcomes | Current open-risk list |
| `wppp_sim/README.md` | Test intent, interface, and maintained status | Production IP equivalence claim |
| `wppp_integration_sim/README.md` | AXI integration topology, endpoint contracts, and integration cases | Full CXL-protocol or active-HPPB coverage claim |
| Prefetch `README.md` | Stable module contracts and integration assumptions | Mutable regression evidence |
| `logs/*/plan.json` | Exact invocation and source state | Final pass/fail result |
| `logs/*/result.json` or `summary.json` | Machine-readable run result | Long-term architecture prose |

When behavior changes, update the module contract, affected test catalog,
`BUG.md`, and `CHANGE.md` in the same change. Add transient command output only
to an ignored run directory.
