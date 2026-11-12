# XR1710G 10G link-up / no-RX recovery

## Evidence and scope

On the tested XR1710G / Marvell AQtion link, Windows boots with a 10G carrier
but zero received packets and no DHCP lease. The router sees client DHCP
Discover packets and upstream Offer replies being sent towards lan2. A
controlled lan2 close/open restores reception and DHCP without changing
cabling, upstream DHCP, Wi-Fi, offloads or link speed. This was reproduced
after a further PC reboot and automatically recovered.

The PHY/PCS registers responsible have NOT been identified. This package is
a bounded automatic-recovery mitigation, not a claim of a driver root-cause
fix. Interface reopen also retrains the peer, so the evidence alone cannot
assign the original defect to one side of the link.

## Recovery behavior

- Restricted to XR1710G board IDs and lan2, at a verified 10G carrier.
- Parse DHCP on Linux cooked v2 captures, including ingress broadcasts.
- Require three ingress Discovers and three matching egress Offers with no
  client Request, over at least eight seconds. Ignore other interfaces and
  transaction IDs. A Request, ACK or NAK clears that transaction.
- Check the port remains bridged, up and at 10G immediately before action.
- Close lan2 for two seconds, then reopen it. Attached devices on this port
  briefly disconnect; WAN and wireless configuration are not changed.
- Limit to one action per 120 seconds and at most four per 15-minute window.
- Track the action budget in /var/run to retain limits across service restart.
- procd supervises the monitor and enables it at boot.

The package depends on tcpdump and ip-full. 1710.config selects it. Repeated
DHCP exchanges are a heuristic; a DHCP server/client incompatibility could
produce similar behavior, which is why recovery is bounded and disableable.

## Control

```sh
/etc/init.d/xr1710g-link-recovery status
cat /var/run/xr1710g-link-recovery/limits
# Disable and stop the mitigation:
uci set xr1710g_link_recovery.main.enabled=0
uci commit xr1710g_link_recovery
/etc/init.d/xr1710g-link-recovery stop
```

## Validation

Seven parser replays cover a genuine stall, a healthy handshake, foreign
interfaces, outgoing client traffic, mismatched transactions, the minimum
observation interval and cooldown. Shell syntax checks passed. Live testing
recovered the fault twice, including after a manual PC reboot, with a DHCP
lease and sustained 10G reception. Factory partitions were not modified.
The firmware containing the package completed a full incremental world
build and XR1710G profile/manifest checks. It has not yet been flashed.
