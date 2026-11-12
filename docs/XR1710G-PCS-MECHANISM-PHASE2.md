# XR1710G PCS mechanism investigation — phase 2

2026-11-13. Experimental results on the original physical 10G LAN port, with the same Marvell AQtion client. The running pcs-test1 workaround remains unchanged. No new firmware was installed during this phase.

## Method

Each independent test started with working reception, temporarily suppressed the port's existing WA, and reproduced failure with a router-driven 10G -> 100M -> 10G advertisement cycle. The old DHCP fallback service was stopped during measurement. A detached controller on the build host continued executing even when the client link failed. Windows NIC receive counters were sampled approximately once per second and aligned to router action markers.

Actions were measured before a separately marked final phylink stop/start cleanup. This distinction prevents crediting the diagnostic action for recovery actually performed by cleanup. A temporary module scheduled a recovery watchdog and restored the original WA on unload. All tests below recorded successful unload and cleanup; advertised modes and the fallback service were restored. Final links were 10G on both ports, wired ICMP passed 3/3, and no kernel BUG/WARNING/Oops was observed.

## Results

| Isolated action | Result before final full recovery |
| --- | --- |
| Driver's USX AN_RESTART sequence (AN_CONTROL_0 bit 8) | No RX increase |
| Clear/reapply USX manual-rate selection (AN_CONTROL_7 bit 12) | No RX increase |
| Clear/reapply rate-adapter force enable (CTRL_11 bit 8) | No RX increase |
| Clear/reapply USX AN enable (AN_CONTROL_0 bit 0) | Link Down/Up and PHY flow_s occurred, but RX stayed zero |
| Combined TX reset fields: bits 10, 7, 6, 2 of PMA SW_RST_SET | No RX increase |
| Combined RX reset fields: bits 11, 9, 8, 1, 0 of PMA SW_RST_SET | No RX increase |
| SW_ALLPCS_RST_N only (SW_RST_SET bit 4), PHY polling active | Recovered twice; measured receive increases of 315551 and 268911 bytes before cleanup |
| SW_ALLPCS_RST_N with PHY polling temporarily paused | No RX increase while polling remained paused; after polling resumed, the PHY performed flow_s and RX increased by 152911 bytes before cleanup |

Failed actions had zero receive-byte increase across their approximately 17-second post-action measurement windows. These are traffic-presence observations, not throughput benchmarks.

## What the smaller successful sequence actually did

The explicit SoC register operation changed only SW_ALLPCS_RST_N, holding it low for 100–200 microseconds then restoring the original register value. It did not rerun the software PLL/PMA bringup sequence or load PHY firmware.

Immediately afterward the USX partner word and AN-complete snapshot became zero, while sampled physical RX link/block-lock indicators remained asserted. phylink reported a normal link-down event. With PHY polling active, the RTL8261BE driver detected carrier loss with copper still linked and performed its existing SerDes flow_s retry; a normal link-up and reception followed. No PCS major-configuration event occurred until the later explicitly marked cleanup.

In the controlled polling-pause case, the same SoC operation did not recover data during the observation interval. Resuming the PHY state machine triggered flow_s and restored data. The Airoha rxlock_next bookkeeping stayed zero in both slots throughout that experiment. In the matching source, the RX-lock workaround updates that field after performing a CDR reset. Thus that software CDR recovery path did not explain this recovery. This does not exclude undocumented internal hardware effects of a reset line.

**Important limitation:** the PHY retry is necessary to re-establish the link after this disruptive SoC reset. That does not by itself prove that the PHY was originally defective, or that both endpoints had independently failed. The reset itself clears negotiation state and creates a fresh synchronization requirement.

AN-enable cycling also produced link-down, PHY flow_s, and link-up, yet did not restore RX. Therefore merely refreshing negotiation or provoking a PHY retry is insufficient. The evidence points beyond a missing AN-restart callback, toward retained PCS data-path/rate-adaptation state. The precise FIFO, clock-domain crossing, or state-machine failure is not yet proven.

Separately resetting TX and RX groups does not exclude a need to reset both groups simultaneously. A simultaneous child-domain reset excluding ALLPCS/PMA/reference reset has not been tested.

## Newly located SDK evidence and next targeted tests

Public SDK source was located and pinned to commit 32b5aa356c2406edef8806aaf75451ff0a5286f2 in lotusmomo/airoha_sdk. It provides generated rate-adapter register definitions missing from the current Linux header:

- Rate-adapter CTRL_0 bits 16/17 clear the TX asynchronous FIFO write/read sides; bits 18/19 clear the RX sides. These belong to the rate adapter, not the PMA TX_FIFO reset previously tested.
- CTRL_0 bits 26/27 are TX/RX bypass selections.
- Read-only status offsets 0x34/0x38 count TX XFI SOP/EOP, and 0x3c/0x40 count TX MAC SOP/EOP. Further RX/error/FIFO status registers allow boundary comparisons. Counter sampling/latch semantics must be validated before interpreting stationary counts.
- The SDK's fixed-rate 10G path sets bypass, while its lower fixed-rate paths clear it. Its automatic-negotiation setup also clears bypass. These are different operating paths: this is a useful controlled comparison, **not proof that every in-band 10G link must bypass adaptation**.
- The SDK differentiates forced-rate control and AN-driven control. The current Linux path forces speed from software; the effect of this difference has not been isolated.

The next useful experiment is to compare normal versus failed MAC-side/XFI-side counter deltas, then independently test rate-adapter FIFO clear and the appropriate 10G bypass path. Those controls have not been exercised in this phase. A read-only counter collector has been prepared offline, without software latch writes or packet-payload register reads; it has not been run on the router.

The known-good WA is retained. No smaller reset has been promoted to a permanent fix, and no unverified changes were merged into the main branch. Further network-interrupting experiments require advance notice and an available test window.

## Source references

- [Pinned SDK Ethernet SerDes implementation](https://github.com/lotusmomo/airoha_sdk/blob/32b5aa356c2406edef8806aaf75451ff0a5286f2/linux/arch/arm64/mach-econet/sgmii/air_eth_xsgmii.c)
- [Pinned SDK rate-adapter field definitions](https://github.com/lotusmomo/airoha_sdk/blob/32b5aa356c2406edef8806aaf75451ff0a5286f2/linux/arch/arm64/mach-econet/sgmii/H/rate_adaption_csr_XGMII_hal_reg.h)
- [Pinned SDK register offsets](https://github.com/lotusmomo/airoha_sdk/blob/32b5aa356c2406edef8806aaf75451ff0a5286f2/linux/arch/arm64/mach-econet/sgmii/H/rate_adaption_csr_XGMII_reg.h)
- [phylink's intentional AN-restart filtering discussion](https://lists.openwall.net/netdev/2020/06/26/86)

The reference SDK's older prebuilt modules were inspected only on the build host, never loaded on the router. The tests used temporary modules built against the running pcs-test1 kernel's exact private headers and exported-symbol table. Diagnostic modules should not be reused against a different kernel/private ABI.
