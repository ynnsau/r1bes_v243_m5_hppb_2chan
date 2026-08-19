# Agilex CXL Type-2 WPPP Hardware

This repository contains the Altera Agilex CXL Type-2 design historically named
`r1bes_v243_m5_hppb_2chan`. The current documentation and verification focus is
the write-push prefetch path (WPPP) under
`hardware_test_design/common/prefetch`.

This file is the stable project overview. Current issue state, detailed handoff
notes, run evidence, and operating procedure have separate owners; start with
the [documentation map](docs/README.md) before adding debug notes.

## WPPP at a Glance

```text
host write to configured hint page
        |
        v
afu_top / wppp_hint_snoop: unpack eight {reserved, 16-bit count, VA[47:6]} slots
        |
        v
wppp_translation_stage: 4 KiB split -> banked cache -> delayed fill -> PA guard
        |
        +-------------- retained slot selector -------------+
        v                                             v
WPPP engine 0                                  WPPP engine 1
        |                                             |
        | device-biased 64-byte AXI reads             |
        v                                             v
ID-to-address LUT -> response pipeline -> NCP writeback to the same address
        |                                             |
        +---------- AXI arbitration with HPPB --------+
                              |
                              v
                       CXL/HDM channels 0 and 1
```

The active implementation adds a 2 GiB-coverage, four-bank/eight-way
translation cache in front of two `wppprefetch_rw_pipeline_v2` instances. A
cold page miss is dropped, serviced for 128 cycles, and inserted; a later hint
can hit and reach WPPP. Each engine issues cacheline reads with 10-bit rotating
request IDs, restores the original address when responses return out of order,
and writes each payload back as an NCP request. HPPB no longer participates in
WPPP lookup or admission.
See the [WPPP module contract](hardware_test_design/common/prefetch/README.md)
and [engineering handoff](PROJECT.md) for exact behavior and known limitations.

At the host-facing project boundary, AW and W for each host-originated write
are assumed to be presented and accepted synchronously. The hint snoop relies
on this contract: it qualifies on AWVALID and samples WDATA in that same cycle.
Independently timed host AW/W handshakes are not supported by the current
integration. (The WPPP-generated NCP path has its own AW-then-W behavior.)

## Quick Start

Simulation uses the Questa installation shipped with the Quartus 26.1 module:

```bash
module load quartus/26.1
make sim-smoke
make sim-focused
make sim-full
make sim-repro
make sim-integration-smoke
make sim-integration-focused
make sim-integration-full
```

The `wppp_sim` targets isolate the production pipeline and retain the known-bug
reproducers. The separate integration targets add the real hint snoop, both
WPPP engines, final HPPB arbiters, an AXI-level fake CXL IP, a device-side fake
MC, and host-side CPU sinks. Their wrapper explicitly selects the historical
direct-PA compatibility mode, so these cases preserve established AXI coverage
but do not verify the new cache. They do not model the CXL wire protocol. See
the [integration simulation guide](wppp_integration_sim/README.md).

Quartus project validation remains on the project-matched 25.3 release:

```bash
module load quartus/25.3
make quartus-preflight
make quartus-quick
# Long run, when full implementation and timing evidence are required:
make quartus-full
```

In the current checkout, preflight reports missing generated IP synthesis
collateral. Use `make quartus-ip-plan` to print the exact recovery command;
review it before generation because it covers 27 project IP descriptors and
may update large generated trees.

Regression and compile targets send best-effort start/completion/error pings by
default. Use `WORKFLOW_NOTIFY=0` for a deliberately silent local run. No
credential is stored in the repository.

## Documentation

- [Documentation ownership map](docs/README.md)
- [Engineering handoff](PROJECT.md)
- [Required workflow and acceptance gates](WORKFLOW.md)
- [Local machine setup](README_LOCAL_MACHINE.md)
- [Known issue index](BUG.md)
- [Reverse-chronological change log](CHANGE.md)
- [Standalone WPPP simulation](wppp_sim/README.md)
- [AXI-level WPPP integration simulation](wppp_integration_sim/README.md)
- [Workflow tool reference](tools/README.md)
