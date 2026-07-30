#!/bin/bash
# setup-kali-vlan.sh
# Run as root on Kali-Attacker.
# Configures persistent VLAN 30 (Attacker zone) tagging via /etc/network/interfaces,
# matching docs/04-installation/kali-attacker.md.

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Run this as root: sudo bash setup-kali-vlan.sh"
  exit 1
fi

IFACE="eth0"
VLAN_ID="30"
VLAN_IFACE="${IFACE}.${VLAN_ID}"
IP_ADDR="10.10.30.10"
GATEWAY="10.10.30.1"
WIN_ZONE="10.10.50.0/24"

echo "== Configuring $VLAN_IFACE ($IP_ADDR/24, gateway $GATEWAY) =="

# Ensure the 8021q kernel module is available
modprobe 8021q || true
grep -qxF '8021q' /etc/modules || echo '8021q' >> /etc/modules

# Back up the existing interfaces file once
if [ ! -f /etc/network/interfaces.bak ]; then
  cp /etc/network/interfaces /etc/network/interfaces.bak
  echo "Backed up existing /etc/network/interfaces to /etc/network/interfaces.bak"
fi

# Append the VLAN 30 stanza if it isn't already present
if ! grep -q "iface ${VLAN_IFACE} inet static" /etc/network/interfaces; then
  cat >> /etc/network/interfaces <<EOF

auto ${VLAN_IFACE}
iface ${VLAN_IFACE} inet static
    address ${IP_ADDR}
    netmask 255.255.255.0
    gateway ${GATEWAY}
    vlan-raw-device ${IFACE}
    up ip route add ${WIN_ZONE} via ${GATEWAY} dev ${VLAN_IFACE}
EOF
  echo "Added ${VLAN_IFACE} stanza to /etc/network/interfaces"
else
  echo "${VLAN_IFACE} stanza already present, skipping"
fi

echo "== Bringing the interface up =="
ifdown "${VLAN_IFACE}" 2>/dev/null || true
ifup "${VLAN_IFACE}"

echo
echo "== Verification =="
ip addr show "${VLAN_IFACE}"
ip route | grep "${VLAN_IFACE}"

echo
echo "Done. Reboot to confirm persistence: sudo reboot"
