# Parse tcpdump -i any -tt -e -vv output (Linux cooked v2).
# Incoming broadcasts have direction B; only Out is egress.
function clear(k) {
    delete discovers[k]; delete offers[k]; delete first[k]; delete seen[k]
}
function valid_mac(mac, a, n, i) {
    n = split(mac, a, ":")
    if (n != 6) return 0
    for (i = 1; i <= n; i++)
        if (a[i] !~ /^[0-9a-f][0-9a-f]$/) return 0
    return 1
}
/^[0-9]+\.[0-9]+[[:space:]]/ {
    now = int($1); iface = $2; direction = $3
    xid = ""; mac = ""
    # Bound stale transaction state even on a busy broadcast domain.
    for (k in seen) if (now - seen[k] > 90) clear(k)
    next
}
/BOOTP\/DHCP/ {
    if (match($0, /xid 0x[0-9a-fA-F]+/)) {
        xid = substr($0, RSTART + 4, RLENGTH - 4)
        xid = tolower(xid)
    }
    next
}
/Client-Ethernet-Address/ { mac = tolower($2); next }
/DHCP-Message/ {
    if (iface != port || xid == "" || !valid_mac(mac)) next
    key = mac SUBSEP xid
    type = $NF
    if (direction != "Out" && type == "Discover") {
        if (!(key in first)) first[key] = now
        discovers[key]++; seen[key] = now
    } else if (direction != "Out" && type == "Request") {
        # The client accepted an offer: this is not the no-RX signature.
        clear(key)
    } else if (direction == "Out" && (type == "ACK" || type == "NAK")) {
        clear(key)
    } else if (direction == "Out" && type == "Offer" && key in discovers) {
        offers[key]++; seen[key] = now
        if (discovers[key] >= 3 && offers[key] >= 3 &&
            now - first[key] >= 8 &&
            (!(port in recovered) || now - recovered[port] >= 120)) {
            printf "%s %s %s\n", port, mac, xid
            fflush()
            recovered[port] = now
            clear(key)
        }
    }
}
