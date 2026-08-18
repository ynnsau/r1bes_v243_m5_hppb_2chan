# WPPP AXI-Level Integration Simulation

This directory verifies the full WPPP data path at the AXI boundary without
modeling the CXL wire protocol. It is separate from `wppp_sim`, so the existing
standalone pipeline cases and known-defect reproducers remain unchanged.

## Wrapping Level

The DUT wrapper keeps the production logic that determines WPPP behavior:

- `wppp_hint_snoop`: observes a host write to the configured hint page and
  emits its eight packed hints;
- `page_tbl_update`: applies the HPPB page-residency filter;
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
                 hint snoop -> page table -> two WPPP engines
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

The behavioral FIFO and LUT models are reused from `wppp_sim`; only the
page-table RAM model is integration-specific.

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
- HPPB is inactive. Its input arrays and update pulse are tied to zero, its AXI
  request ports are stubbed inactive, and the testbench treats any HPPB request
  activity as an error while WPPP traffic is running.

## Maintained Tests

| Test | Tier | What it proves |
| --- | --- | --- |
| `RUN_INT_HOST_RW` | Smoke | An ordinary paired host write/read passes through fake CXL IP, the wrapper, and fake MC without creating WPPP or HPPB traffic. |
| `RUN_INT_SINGLE_HINT` | Smoke | One four-cacheline hint causes four device DB reads and four matching CPU NCP writes on engine 0. |
| `RUN_INT_HINT_BATCH` | Focused | All eight packed hints survive snoop/page-table delay, alternate across both engines, and copy 16 cachelines to the correct CPU sinks. |
| `RUN_INT_HOST_AND_HINT` | Focused | Ordinary host memory traffic completes while WPPP DB reads and NCP writes are active. |
| `RUN_INT_HPPB_INACTIVE` | Full | The dual-engine batch completes with zero HPPB request activity or interference. |

The batch uses two cachelines per packed entry. A one-cacheline head can be
dequeued before its first AR is eligible or accepted due to open issue
`WPPP-AR-DEQUEUE-001`; the original standalone expected-fail case remains the
authoritative reproducer for that production defect.

## Commands and Evidence

Load Questa through the Quartus 26.1 module and run from the repository root:

```bash
module load quartus/26.1
make sim-integration-smoke
make sim-integration-focused
make sim-integration-full
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

1. programmable AR/R latency and backpressure on each fake-MC DB port;
2. AW, W, and B backpressure at each CPU sink;
3. out-of-order DB responses across multiple outstanding IDs;
4. page-table backdoor setup proving host-resident hints are suppressed while
   neighboring device-resident hints proceed;
5. reset, enable, LUT-flush, maximum-count, ID-wrap, and address-boundary cases;
6. error-response injection once the expected WPPP policy for RRESP/BRESP is
   specified.

Activating HPPB, modeling migration updates concurrently, or checking the CXL
protocol itself requires a broader wrapper and is intentionally outside this
suite.
