# WPPP AXI-Level Integration Simulation

This directory verifies the full WPPP data path at the AXI boundary without
modeling the CXL wire protocol. It is separate from `wppp_sim`, so the existing
standalone pipeline cases and known-defect reproducers remain unchanged.

## Wrapping Level

The DUT wrapper keeps the production logic that determines WPPP behavior:

- `wppp_hint_snoop`: observes a host write to the configured hint page and
  emits its eight packed hints in explicit legacy format;
- `wppp_translation_stage`: instantiated with `LEGACY_DIRECT_MODE=1`, making
  the old direct-PA regression path explicit without claiming cache coverage;
- both `wppprefetch_rw_pipeline_v2` engines, including their hint FIFOs,
  request-ID LUTs, response paths, and NCP writers;
- both final production `axi_arbiter` instances.

The wrapper deliberately excludes the CXL hard IP, full `afu_top`, CSR fabric,
memory-controller IP, and active HPPB engines. Their relevant AXI behavior is
represented by small behavioral endpoints:

```text
host AXI agent
      |
      v
fake_cxlip host ingress -> WPPP integration wrapper -> fake_mc host port
                                  |
                 hint snoop -> legacy stage -> two WPPP engines
                                              |              |
                         device-biased AR ---+              +--- NCP AW/W
                                             v                  v
                                      fake_cxlip           fake_cxlip
                                             |              CPU sinks
                                             v
                                      fake_mc DB ports
```

This is the intended level for injecting hint-page writes and ordinary memory
requests, then checking the resulting device-side reads and host-side push
writes. It validates the AXI contract and production WPPP stages while keeping
simulation fast and deterministic.

## Endpoint Responsibilities

`fake_cxlip` is an AXI router/sink, not a CXL protocol model. It:

- passes ordinary host AXI reads and writes through the wrapper to the MC;
- forwards each WPPP device-biased AR to the corresponding fake-MC DB port;
- terminates each WPPP NCP write in a channel-specific host/CPU memory sink;
- checks the NCP request shape, full-line byte strobes, and six-bit AXI-user
  value after the production interface truncation.

`fake_mc` provides one shared sparse device-memory image. Its host port accepts
ordinary full AXI reads/writes, and its two queued DB ports return WPPP reads
with fixed latency. It checks address range, one-beat 64-byte request shape,
and `aruser=6'b110000`. The CPU sinks are intentionally separate: a WPPP read
comes from device memory, while the final NCP write goes to host memory.

The behavioral FIFO and LUT models are reused from `wppp_sim`.

The production translated-path top compiles the generated simulation wrappers
and cores for `fifo_81b_32d` and `bram_b512_d16384`. The load step uses the
`altera_mf_ver` and `altera_lnsim_ver` libraries supplied by the required
Quartus 26.1 module, so the tested FIFO latency, byte enables, `OLD_DATA`
collision behavior, and two-cycle RAM read come from the vendor models.

## Legacy Compatibility Boundary

The maintained vectors were written before the translation-cache format and
encode each slot as `{count[13:0], direct_PA[49:0]}`. The wrapper therefore
sets both compatibility parameters explicitly:

```systemverilog
wppp_hint_snoop #(.LEGACY_HINT_FORMAT(1'b1)) ...
wppp_translation_stage #(.LEGACY_DIRECT_MODE(1'b1)) ...
```

This mode bypasses cache lookup, translation latency, page splitting, PA-side
range guarding, MSHR behavior, and cache flush. It exists solely so changes to
the production front end do not silently reinterpret old cases. Production
selects the new 16/42 decoder and translated path; that mode needs a separate
directed test set.

## Explicit Contracts

- Host-originated writes present AW and W together and both handshakes complete
  in the same clock cycle. The production hint snoop relies on this project
  contract: it qualifies on AWVALID and samples WDATA in that cycle.
  Independently timed host AW/W writes are outside this integration scope; the
  WPPP-generated NCP path still uses its production AW-then-W sequence.
- A write anywhere in the configured 4 KiB hint page carries eight packed
  `{14-bit cacheline count, 50-bit address}` entries.
- WPPP database reads originate on the device side and reach the fake MC.
- WPPP NCP writes terminate in the host/CPU-side sinks and do not modify the
  fake-MC device-memory image.
- HPPB is inactive. Its AXI request ports are stubbed inactive, and the
  testbench treats any HPPB request activity as an error while WPPP runs. No
  HPPB page-table filter exists in the WPPP wrapper.

## Maintained Tests

| Test | Tier | What it proves |
| --- | --- | --- |
| `RUN_INT_HOST_RW` | Smoke | An ordinary paired host write/read passes through fake CXL IP, the wrapper, and fake MC without creating WPPP or HPPB traffic. |
| `RUN_INT_SINGLE_HINT` | Smoke | One four-cacheline hint causes four device DB reads and four matching CPU NCP writes on engine 0. |
| `RUN_INT_HINT_BATCH` | Focused | All eight packed legacy hints survive serialization, alternate across both engines, and copy 16 cachelines to the correct CPU sinks. |
| `RUN_INT_HOST_AND_HINT` | Focused | Ordinary host memory traffic completes while WPPP DB reads and NCP writes are active. |
| `RUN_INT_HPPB_INACTIVE` | Full | The dual-engine batch completes with zero HPPB request activity or interference. |
| `RUN_INT_DB_BACKPRESSURE` | Stress | Holds the first and final AR, disables new prefetch work during the final stall, and verifies stable delivery plus exact end-to-end copies. |
| `RUN_INT_NCP_BACKPRESSURE` | Stress | Independently holds NCP AW and W, checks stable payloads, holds BVALID low through the transfer while checking BREADY, and verifies exact CPU writes. |
| `RUN_INT_OUT_OF_ORDER` | Stress | Captures four requests from each engine, returns each channel in reverse ID order, and checks LUT-based address/data restoration. |
| `RUN_INT_HINT_SEQUENCE` | Stress | Checks an off-page write, sparse/zero slots, two safely separated hint lines, selector continuity, both engines, and exact copied data. |
| `RUN_INT_ATC_COLD_HIT` | ATC | Uses the production 16/42 record: the first reference misses and is dropped, the 128-cycle service inserts one translation, and a repeated reference hits and completes exact fake-MC-to-CPU copies. |

The request stage now transfers each FIFO head into an active-hint register.
One-cacheline hints and final cachelines therefore remain owned by the request
stage until their AR handshakes, including while enable is deasserted after a
stalled request has already been presented.

## Commands and Evidence

Load Questa through the Quartus 26.1 module and run from the repository root:

```bash
module load quartus/26.1
make sim-integration-smoke
make sim-integration-atc
make sim-integration-focused
make sim-integration-full
make sim-integration-stress
```

The equivalent local targets are:

```bash
make -C wppp_integration_sim sim-full JOBS=4 WORKFLOW_NOTIFY=0
make -C wppp_integration_sim sim \
  SIM_PLUSARGS='+RUN_INT_SINGLE_HINT +WPPP_INT_TRACE' \
  WORKFLOW_NOTIFY=0
```

Tier targets compile once, schedule cases in parallel, require the exact
`WPPP_TEST_PASS: <test>` marker, reject integration/Questa error markers,
compress passing transcripts, rerun failures verbosely, and write `plan.json`,
per-test results, and `summary.json` beneath `wppp_integration_sim/logs/`.
They send one best-effort aggregate start and finish/error ping by default;
set `WORKFLOW_NOTIFY=0` for a silent local run.

## Natural Next Cases

The next useful extensions at this same wrapping level are:

1. a new-mode wrapper configuration with small cache geometry covering cold
   miss, 128-cycle fill, later hit, coalescing, page splitting, PA rejection,
   replacement, capacity drops, and flush;
2. reset, enable, LUT-flush, maximum-count, ID-wrap, and address-boundary cases;
3. error-response injection once the expected WPPP policy for RRESP/BRESP is
   specified;
4. a defined producer contract or queue for a second hint-line write arriving
   before the current eight-slot serialization completes.

Activating HPPB, modeling migration updates concurrently, or checking the CXL
protocol itself requires a broader wrapper and is intentionally outside this
suite.
