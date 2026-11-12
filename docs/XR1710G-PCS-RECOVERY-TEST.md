# XR1710G PCS recovery candidate (experimental)

2026-11-12: A wired Marvell AQtion client repeatedly negotiates 10 Gbit/s after shutdown/start but receives no frames. Incoming DHCP Discover and outgoing Offer had been observed; carrier alone does not indicate a working data path.

## Hardware isolation results

- Failure followed the client when the two RTL8261BE 10G ports were exchanged.
- Disabling the client's power-off wake feature did not prevent it.
- PHY-only reset/firmware initialization did not restore traffic.
- SoC XFI MAC logic reset, rate-adapter enable toggle, HSG TXPCS reset, XFI TXPCS reset, and TX FIFO reset individually did not restore traffic.
- Stopping/starting phylink with the PHY still attached restored traffic repeatedly (four cold-boot cases plus a software speed-cycle case).
- Two same-speed 10G renegotiations preserved reception and bound-source ICMP replies.
- A router-side 10G -> 100M -> 10G advertisement cycle also reproduced stopped receive counters without restarting the PC. Restoring phylink restored reception and bound-source ICMP replies.
- The sampled 22 static configuration registers were identical between failed and recovered 10G states; internal state/order remains under investigation.

These observations identify a reproducible speed-transition problem recoverable through the PCS major-initialization path. They do not identify a single defective register or exclude PHY/PCS interoperability.

## Candidate behavior

The device-tree boolean `airoha,reinit-usxgmii-after-100m` opts in the two XR1710G external USXGMII ports. The driver also requires the RTL8261BE driver. On a reported 100M -> 10G transition it schedules one phylink stop/start, without disconnecting or soft-resetting the PHY and without tearing down bridge membership or shared QDMA queues. Other speed changes do not trigger it.

The worker takes RTNL with trylock; close disables new work, drains phylink resolve callbacks, then synchronously cancels pending work. PHY link/speed is checked under its mutex before recovery. Recovered 10G -> 10G reports do not retrigger the work.

This is a scoped recovery candidate, not a proven fix for the precise internal failure. It adds one additional negotiation interval after the selected speed transition. Existing DHCP recovery remains a fallback.

## Validation

- Driver translation unit cross-compiles against the matching 6.18.60 kernel.
- Patch dry-run applies to the original source files.
- Kernel checkpatch: 0 errors, 0 warnings, 0 checks.
- Full firmware build completed successfully (exit 0). The image contains the opt-in DT property and the recovery log string.
- Image SHA256: `f76315fc97058e259280d74cf228a408cc73c7658967f31270fa2e62163a7f97`.
- SHA256 matched on the build host, local output, and router upload. `sysupgrade -T` passed (exit 0); no image was flashed.
- Candidate-kernel hardware cold boot / close-during-recovery tests are pending. The running router remains on its existing firmware; temporary modules have been unloaded.

## Next device validation

1. Check image SHA256 and run sysupgrade -T against the intended stock-chainloader image.
2. Manually install the test image and return to AP mode if required.
3. Confirm both 10G ports and normal DHCP, then repeat the router-side speed cycle while managing over Wi-Fi.
4. Confirm exactly one recovery log per 100M -> 10G transition, restored RX/DHCP, no repeated reset loop, and unaffected other ports.
5. Test a PC shutdown/start and interface close during a queued recovery.

Keep the previous known-booting image available. Removing the DT boolean disables this candidate behavior in a subsequent build.
