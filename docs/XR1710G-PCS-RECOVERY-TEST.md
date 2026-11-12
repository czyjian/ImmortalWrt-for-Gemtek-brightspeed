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
- SHA256 matched on the build host, local output, and router upload. `sysupgrade -T` passed (exit 0) before the user installed the test image.
- Test firmware was installed on the XR1710G and both opt-in DT properties were confirmed at runtime.
- Three router-side 100M -> 10G cycles each caused exactly one driver recovery and restored reception. Same-speed 10G renegotiations did not add recovery events.
- Closing the interface shortly after 10G link-up, before the 250 ms deferred recovery, then reopening it restored normal operation without an extra recovery or kernel warning. The first shell timing attempt did not enter this window because fractional sleep was unavailable; the successful retry used a userspace millisecond timer.
- A subsequent PC shutdown/start reproduced the low-speed sleeping link then 10G transition. Exactly one automatic driver recovery followed; DHCP ACK was captured and the client received its normal lease. Bound-source ICMP succeeded 3/3, receive counters advanced, and both 10G ports remained at 10G. No fallback reset record or kernel BUG/WARNING/Oops was observed.
- This validates the scoped recovery on the tested client/port; longer-term reliability, direct client testing on the other 10G port, and the precise internal PCS failure remain open.

## Remaining validation

1. Observe ordinary use over a longer period and repeat cold boots when convenient.
2. Validate the same client directly on the other opt-in 10G port before claiming both paths are equally covered.
3. Continue isolating the PCS initialization stages to identify the exact internal failure, rather than treating full reinitialization as proof of a single-register fix.

Keep the previous known-booting image available. Removing the DT boolean disables this candidate behavior in a subsequent build.
