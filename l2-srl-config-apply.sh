#!/usr/bin/env bash
set -euo pipefail

NODES=(leaf1 leaf2 leaf3)
SRCLI="/usr/local/bin/sr_cli"   # fallback path; change if which shows a different path 

CFG=$(cat <<'EOF'
enter candidate

# Downlink vlan 10
set / interface ethernet-1/1 subinterface 10 type bridged
set / interface ethernet-1/1 subinterface 10 description bd1
set / interface ethernet-1/1 subinterface 10 admin-state enable
set / interface ethernet-1/1 subinterface 10 vlan encap single-tagged vlan-id 10

# tunnel interface
set / tunnel-interface vxlan0 vxlan-interface 1 type bridged
set / tunnel-interface vxlan0 vxlan-interface 1 ingress vni 1
set / tunnel-interface vxlan0 vxlan-interface 1 egress source-ip use-system-ipv4-address

# mac vrf
set / network-instance mac-vrf-1
set / network-instance mac-vrf-1 type mac-vrf
set / network-instance mac-vrf-1 admin-state enable
set / network-instance mac-vrf-1 interface ethernet-1/1.10
set / network-instance mac-vrf-1 vxlan-interface vxlan0.1
set / network-instance mac-vrf-1 protocols
set / network-instance mac-vrf-1 protocols bgp-evpn
set / network-instance mac-vrf-1 protocols bgp-evpn bgp-instance 1
set / network-instance mac-vrf-1 protocols bgp-evpn bgp-instance 1 vxlan-interface vxlan0.1
set / network-instance mac-vrf-1 protocols bgp-evpn bgp-instance 1 evi 1
set / network-instance mac-vrf-1 protocols bgp-evpn bgp-instance 1 ecmp 8
set / network-instance mac-vrf-1 protocols bgp-vpn
set / network-instance mac-vrf-1 protocols bgp-vpn bgp-instance 1
set / network-instance mac-vrf-1 protocols bgp-vpn bgp-instance 1 route-target
set / network-instance mac-vrf-1 protocols bgp-vpn bgp-instance 1 route-target export-rt target:100:1
set / network-instance mac-vrf-1 protocols bgp-vpn bgp-instance 1 route-target import-rt target:100:1

commit save
exit
EOF
)

for n in "${NODES[@]}"; do
  echo "===== $n ====="
  docker exec "$n" sh -lc "command -v sr_cli >/dev/null 2>&1 || echo 'sr_cli missing'"
  docker exec -i "$n" "$SRCLI" <<< "$CFG" 2>&1 | sed "s/^/[$n] /"
  echo "===== $n done ====="
done

