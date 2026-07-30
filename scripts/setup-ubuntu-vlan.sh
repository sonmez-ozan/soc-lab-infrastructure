#!/bin/bash
# setup-ubuntu-vlan.sh
# Run as root on Ubuntu-Victim.
# Configures persistent VLAN 20 (Victims zone) tagging via /etc/rc.local,
# matching docs/04-installation/ubuntu-victim.md.
#
# rc.local is used instead of netplan's native `vlans:` key — netplan's schema
# repeatedly rejected the VLAN interface on this environment (see
# docs/05-lessons-learned.md), and rc.local proved reliable once its two
# real bugs (a typo, and a missing default route) were fixed.

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Run this as root: sudo bash setup-ubuntu-vlan.sh"
  exit 1
fi

IFACE="enp0s3"
VLAN_ID="20"
VLAN_IFACE="${IFACE}.${VLAN_ID}"
IP_ADDR="10.10.20.10"
GATEWAY="10.10.20.1"

echo "== Installing VLAN tooling =="
apt-get update -qq
apt-get install -y vlan >/dev/null

echo "== Writing /etc/rc.local =="
cat > /etc/rc.local <<EOF
#!/bin/bash
modprobe 8021q
ip link add link ${IFACE} name ${VLAN_IFACE} type vlan id ${VLAN_ID}
ip addr add ${IP_ADDR}/24 dev ${VLAN_IFACE}
ip link set ${VLAN_IFACE} up
ip route add default via ${GATEWAY} dev ${VLAN_IFACE} metric 50
exit 0
EOF

chmod +x /etc/rc.local
systemctl enable rc-local >/dev/null 2>&1 || true
systemctl restart rc-local

echo
echo "== Verification =="
sleep 2
ip addr show "${VLAN_IFACE}" || echo "Interface not up yet — check 'sudo systemctl status rc-local' and journalctl for errors"
ip route | grep "${VLAN_IFACE}" || true

echo
echo "Done. Reboot to confirm persistence: sudo reboot"
echo "After reboot, verify with: ip addr show ${VLAN_IFACE} && ip route"
