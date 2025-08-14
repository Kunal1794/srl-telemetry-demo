#!/usr/bin/env bash
set -euo pipefail

NODES=(leaf1 leaf2 leaf3)
SRCLI="/usr/local/bin/sr_cli"   # change if sr_cli lives elsewhere

# Per-node IPs and VLANs
declare -A IP=(
  [leaf1]="10.1.1.254/24"
  [leaf2]="10.2.2.254/24"
  [leaf3]="10.3.3.254/24"
)
declare -A VLAN=(
  [leaf1]="11"
  [leaf2]="12"
  [leaf3]="13"
)

CFG=$(cat <<'EOF'
enter candidate

# Downlink vlan __VLAN__
set / interface ethernet-1/1 subinterface __VLAN__ type routed
set / interface ethernet-1/1 subinterface __VLAN__ admin-state enable
set / interface ethernet-1/1 subinterface __VLAN__ ipv4 admin-state enable
set / interface ethernet-1/1 subinterface __VLAN__ ipv4 address __IP__
set / interface ethernet-1/1 subinterface __VLAN__ vlan encap single-tagged vlan-id __VLAN__

# tunnel interface (unchanged)
set / tunnel-interface vxlan0 vxlan-interface 2 type routed
set / tunnel-interface vxlan0 vxlan-interface 2 ingress vni 2
set / tunnel-interface vxlan0 vxlan-interface 2 egress source-ip use-system-ipv4-address

# ip vrf
set / network-instance ip-vrf1 type ip-vrf
set / network-instance ip-vrf1 admin-state enable
set / network-instance ip-vrf1 description ip-vrf1
set / network-instance ip-vrf1 interface ethernet-1/1.__VLAN__
set / network-instance ip-vrf1 vxlan-interface vxlan0.2
set / network-instance ip-vrf1 protocols bgp-evpn bgp-instance 1 vxlan-interface vxlan0.2
set / network-instance ip-vrf1 protocols bgp-evpn bgp-instance 1 evi 2
set / network-instance ip-vrf1 protocols bgp-evpn bgp-instance 1 ecmp 8
set / network-instance ip-vrf1 protocols bgp-evpn bgp-instance 1 routes route-table mac-ip advertise-gateway-mac true
set / network-instance ip-vrf1 protocols bgp-vpn bgp-instance 1 route-target export-rt target:101:1
set / network-instance ip-vrf1 protocols bgp-vpn bgp-instance 1 route-target import-rt target:101:1

commit save
exit
EOF
)

for n in "${NODES[@]}"; do
  echo "===== $n ====="
  docker exec "$n" sh -lc "command -v sr_cli >/dev/null 2>&1 || echo 'sr_cli missing'"

  CFG_NODE="${CFG//__IP__/${IP[$n]}}"
  CFG_NODE="${CFG_NODE//__VLAN__/${VLAN[$n]}}"

  docker exec -i "$n" "$SRCLI" <<< "$CFG_NODE" 2>&1 | sed "s/^/[$n] /"
  echo "===== $n done ====="
done

