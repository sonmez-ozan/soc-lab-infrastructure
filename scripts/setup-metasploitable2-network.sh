#!/bin/bash
# setup-metasploitable2-network.sh
# Run as root (or via sudo) on Metasploitable2-Victim.
# Configures a persistent static IP on eth0 for the Legacy zone via
# /etc/network/interfaces, matching docs/04-installation/metasploitable2-victim.md.
#
# Metasploitable2 can't do VLAN tagging (Ubuntu 8.04, dead package repos,
# no vconfig/8021q available) — it uses a dedicated VirtualBox Internal
# Network (soclab-legacy) instead. See docs/adr/008-legacy-and-windows-zones-for-non-taggable-hosts.md.

IFACE="eth0"
IP_ADDR="10.10.40.10"
NETMASK="255.255.255.0"
GATEWAY="10.10.40.1"

echo "== Writing /etc/network/interfaces =="
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ${IFACE}
iface ${IFACE} inet static
    address ${IP_ADDR}
    netmask ${NETMASK}
    gateway ${GATEWAY}
EOF

echo "== Restarting networking =="
/etc/init.d/networking restart

echo
echo "== Verification =="
ifconfig "${IFACE}"

echo
echo "Done. Reboot to confirm persistence: sudo reboot"
echo "After reboot, verify with: ifconfig ${IFACE}"
