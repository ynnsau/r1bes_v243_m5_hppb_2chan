# WPPP Address-Translation Cache CSR Reference

This document is the software-visible register contract for the first WPPP
address-translation cache (ATC). The CSR block runs at 125 MHz and the ATC
runs at 400 MHz.

In the table, **Input** means software supplies configuration or a control
event to the ATC. **Output** means software reads state produced by the ATC.
Register indices are `address[21:3]`; byte offsets are relative to the CSR
window.

## Register Map

| Index | Byte offset | Name | Direction / access | Purpose |
| ---: | ---: | --- | --- | --- |
| 66 | `0x210` | `WPPP_ATC_TRANSLATION_OFFSET` | Input, RW | Constant byte offset used as `PA = VA - offset`. Bits `[51:0]` are used; bits `[63:52]` must be zero and bits `[11:0]` must be zero for 4 KiB alignment. Software must keep the value stable while WPPP is active and flush the ATC after changing it. |
| 67 | `0x218` | `WPPP_ATC_FLUSH` | Input, write-one event | Writing one to bit 0, with byte lane 0 enabled, requests a full ATC flush. The register reads as zero. One request toggles the CSR-domain event bit; do not issue another request until the current flush completes. |
| 68 | `0x220` | `WPPP_ATC_STATUS` | Output, RO | ATC readiness, flush state, and live MSHR occupancy; see the field table below. |
| 69 | `0x228` | `WPPP_ATC_HIT_COUNT` | Output, RO | Number of page-fragment lookups that hit. |
| 70 | `0x230` | `WPPP_ATC_MISS_COUNT` | Output, RO | Number of page-fragment lookups that miss. Every miss is counted, including coalesced and dropped misses. |
| 71 | `0x238` | `WPPP_ATC_COALESCED_MISS_COUNT` | Output, RO | Misses that found the same VPN already in an MSHR. These misses are dropped and share the existing eventual insertion. |
| 72 | `0x240` | `WPPP_ATC_UNIQUE_MISS_COUNT` | Output, RO | Misses that successfully allocated a new MSHR and timer slot. |
| 73 | `0x248` | `WPPP_ATC_INSERTION_COUNT` | Output, RO | Translation-cache writes that committed after modeled translation service. |
| 74 | `0x250` | `WPPP_ATC_PA_REJECT_COUNT` | Output, RO | Fragments rejected by the post-translation PA guard, plus translations rejected because the offset is wider than 52 bits or subtraction would underflow. |
| 75 | `0x258` | `WPPP_ATC_INVALID_HINT_COUNT` | Output, RO | Nonzero hint slots rejected for invalid format, reserved bits, or a count greater than 128 cachelines. |
| 76 | `0x260` | `WPPP_ATC_DECODED_FIFO_DROP_COUNT` | Output, RO | Valid decoded hint records dropped because the 32-entry ATC ingress FIFO could not accept them. |
| 77 | `0x268` | `WPPP_ATC_MSHR_ADMISSION_DROP_COUNT` | Output, RO | Unique misses dropped because all eight MSHR ways in the selected hashed set were occupied. |
| 78 | `0x270` | `WPPP_ATC_TIMER_DROP_COUNT` | Output, RO | Unique misses dropped because the selected 128-cycle timer-wheel slot was occupied. |
| 79 | `0x278` | `WPPP_ATC_FLUSH_HINT_DROP_COUNT` | Output, RO | Queued, active, or newly arriving pre-WPPP hint records discarded by a CSR flush. |
| 80 | `0x280` | `WPPP_ATC_MSHR_FLUSH_CANCEL_COUNT` | Output, RO | In-flight unique translations canceled by a CSR flush. |
| 81 | `0x288` | `WPPP_ATC_DECODED_FIFO_FULL_CYCLES` | Output, RO | 400 MHz cycles during which the decoded-hint FIFO reported full. |
| 82 | `0x290` | `WPPP_ATC_TIMER_FULL_CYCLES` | Output, RO | 400 MHz cycles during which the current timer-wheel slot was occupied and could not be released. |
| 83 | `0x298` | `WPPP_ATC_DECODED_FIFO_FULL_EPISODES` | Output, RO | Transitions into the decoded-FIFO-full condition. |
| 84 | `0x2a0` | `WPPP_ATC_TIMER_FULL_EPISODES` | Output, RO | Transitions into the timer-slot-full condition. |
| 85 | `0x2a8` | `WPPP_ATC_MSHR_OCCUPANCY` | Output, RO | Packed current MSHR occupancy and lifetime high-water mark; see the field table below. |
| 86 | `0x2b0` | `WPPP_HINT_LINE_DROP_COUNT` | Output, RO | Complete 512-bit host hint lines dropped because the one-line snoop buffer was occupied. |
| 87 | `0x2b8` | `WPPP_ENGINE0_FIFO_DROP_COUNT` | Output, RO | Translated fragments rejected at WPPP engine 0's ingress FIFO. Under the ready/valid integration this should remain zero. |
| 88 | `0x2c0` | `WPPP_ENGINE1_FIFO_DROP_COUNT` | Output, RO | Translated fragments rejected at WPPP engine 1's ingress FIFO. Under the ready/valid integration this should remain zero. |
| 89 | `0x2c8` | `WPPP_HINT_LINE_FULL_CYCLES` | Output, RO | 400 MHz cycles for which the one-line hint snoop buffer was occupied. |
| 90 | `0x2d0` | `WPPP_ENGINE0_FIFO_FULL_CYCLES` | Output, RO | 400 MHz cycles for which engine 0's ingress FIFO reported full. |
| 91 | `0x2d8` | `WPPP_ENGINE1_FIFO_FULL_CYCLES` | Output, RO | 400 MHz cycles for which engine 1's ingress FIFO reported full. |
| 92 | `0x2e0` | `WPPP_HINT_LINE_FULL_EPISODES` | Output, RO | Occupancy episodes of the one-line hint snoop buffer. |
| 93 | `0x2e8` | `WPPP_ENGINE0_FIFO_FULL_EPISODES` | Output, RO | Transitions into engine 0 FIFO full. |
| 94 | `0x2f0` | `WPPP_ENGINE1_FIFO_FULL_EPISODES` | Output, RO | Transitions into engine 1 FIFO full. |
| 95 | `0x2f8` | Reserved | N/A | Reserved for a future WPPP-specific CSR. Software must ignore reads and write zero. |

## Status Fields

`WPPP_ATC_STATUS` at index 68 has the following fields:

| Bits | Name | Meaning |
| ---: | --- | --- |
| 0 | `ready` | One when no cache sweep is active and lookups may proceed. |
| 1 | `flush_busy` | One while the 16,384-row POR or CSR sweep is active. |
| 2 | `flush_complete` | Set when the most recent sweep completes; cleared when the next flush request reaches the ATC. |
| 16:8 | `mshr_occupancy` | Current number of valid MSHR entries, 0 through 256. |
| 32:24 | `mshr_high_water` | Highest MSHR occupancy observed since power-on reset. |
| all others | Reserved | Read as zero in the current implementation. |

`WPPP_ATC_MSHR_OCCUPANCY` at index 85 contains the same occupancy information
inside the coherent statistics snapshot:

| Bits | Name | Meaning |
| ---: | --- | --- |
| 8:0 | `mshr_occupancy` | Snapshot of current MSHR occupancy. |
| 40:32 | `mshr_high_water` | Snapshot of the lifetime high-water mark. |
| all others | Reserved | Zero. |

## Counter and Clock-Domain Semantics

- All counters are unsigned 64-bit values and wrap modulo 2^64. They clear
  only on the corresponding power-on reset; an ATC flush never clears them.
- CSRs 69 through 94 are copied as one coherent group every 64 fast-clock
  cycles when the previous request has been acknowledged. At 400 MHz, a new
  source snapshot is attempted every 160 ns. CSR visibility also includes the
  request/acknowledge clock-domain crossing, so software must not treat these
  registers as cycle-current values.
- CSR 68 is a separately synchronized live status bus, not part of the
  coherent counter snapshot. Software should poll stable level fields rather
  than infer an exact fast-clock transition time.
- CSR 66 crosses to the fast domain through a three-stage bit synchronizer.
  The design assumes this rarely changed multi-bit value is held stable;
  software must not update it during active translation traffic.

## Related Existing CSRs

The ATC consumes these established WPPP/project registers; they were not added
as part of the ATC range:

| Index | Name | Relationship to the ATC |
| ---: | --- | --- |
| 10 | `CXL_START_PA` | Start of the permitted translated-PA push range. |
| 16 | `CSR_ADDR_UB` | Size of that range. The guard accepts the half-open interval `[CXL_START_PA, CXL_START_PA + CSR_ADDR_UB)`. |
| 60 | `PREFETCH_INTERVAL` | Bit 31 enables WPPP hint admission. |
| 64 | `HINT_MECH_ADDR` | Identifies the 4 KiB host hint page. |

## Programming Sequence

1. Clear `PREFETCH_INTERVAL[31]` so new hints are not admitted.
2. Program `CXL_START_PA`, `CSR_ADDR_UB`, and the page-aligned
   `WPPP_ATC_TRANSLATION_OFFSET`.
3. Write one to `WPPP_ATC_FLUSH[0]`.
4. Poll `WPPP_ATC_STATUS` until `flush_busy == 0`, `ready == 1`, and
   `flush_complete == 1`.
5. Set `PREFETCH_INTERVAL[31]` when traffic may resume.

The POR sweep also holds `ready` low for 16,384 fast-clock cycles, approximately
40.96 microseconds at 400 MHz. A flush discards pre-WPPP queued and active
fragments and cancels translations in flight. Fragments already accepted by a
WPPP engine FIFO continue normally.
