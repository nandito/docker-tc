#!/usr/bin/env bash
QDISC_ID=
QDISC_HANDLE=
tc_init() {
    QDISC_ID=1
    QDISC_HANDLE="root handle $QDISC_ID:"
    ip link set dev ifb0 up
}
qdisc_del() {
    tc qdisc del dev "$1" root
    tc qdisc del dev ifb0 root
}
qdisc_next() {
    QDISC_HANDLE="parent $QDISC_ID: handle $((QDISC_ID+1)):"
    ((QDISC_ID++))
}
# Following calls to qdisc_netm and qdisc_tbf are chained together
# http://man7.org/linux/man-pages/man8/tc-netem.8.html
qdisc_netm() {
    IF="$1"
    shift
    tc qdisc add dev "$IF" $QDISC_HANDLE netem $@
    tc qdisc add dev ifb0 $QDISC_HANDLE netem $@
    qdisc_next
}
# http://man7.org/linux/man-pages/man8/tc-tbf.8.html
qdisc_tbf() {
    IF="$1"
    shift
    tc qdisc add dev "$IF" $QDISC_HANDLE tbf burst 5kb latency 50ms $@
    tc qdisc add dev ifb0 $QDISC_HANDLE tbf burst 5kb latency 50ms $@
    qdisc_next
}
qdisc_set_mirred() {
    # clear previous configuration
    if ! tc qdisc del dev ifb0 root 2>/dev/null; then
        echo "[WARN] tc qdisc del dev ifb0 root failed. Maybe it's already cleared."
    fi
    # add new configuration
    IF="$1"
    tc qdisc add dev "$IF" ingress
    echo "[DEBUG] tc qdisc add dev "$IF" ingress"
    tc filter add dev "$IF" parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0
    echo "[DEBUG] tc filter add dev "$IF" parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0"
}
