#!/bin/bash
# provision-pfsense-networks.sh
#
# Run on the Windows host via Git Bash (or WSL, adjusting the VBoxManage path).
# Creates the VirtualBox Internal Networks this lab depends on and attaches the
# 5th NIC to pfSense-Gateway, since VirtualBox's GUI Settings dialog only exposes
# 4 network adapter tabs per VM.
#
# Run this BEFORE assigning interfaces inside the pfSense console/GUI.
# Safe to re-run — VBoxManage no-ops on attachments that already match.

set -e

VBOXMANAGE="/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"
VM_NAME="pfSense-Gateway"

if [ ! -f "$VBOXMANAGE" ]; then
  echo "VBoxManage not found at: $VBOXMANAGE"
  echo "Edit the VBOXMANAGE path in this script to match your VirtualBox install location."
  exit 1
fi

echo "== Provisioning VirtualBox Internal Networks for soc-lab-infrastructure =="

# Internal Networks used by this lab:
#   soclab-net     - trunk carrying VLAN 20 (Victims) + VLAN 30 (Attacker), shared by Kali & Ubuntu
#   soclab-legacy  - dedicated network for Metasploitable2 (can't do VLAN tagging)
#   soclab-win     - dedicated network for Windows 11 (NIC driver has no VLAN ID field)
#
# VirtualBox creates Internal Networks implicitly the first time a VM adapter
# references the name, so there's no separate "create network" step — attaching
# a NIC to the name is what creates it.

echo "-- Adapter 2 (em1) -> soclab-net (VLAN trunk: Victims + Attacker) --"
"$VBOXMANAGE" modifyvm "$VM_NAME" --nic2 intnet --intnet2 "soclab-net" --cableconnected2 on

echo "-- Adapter 3 (em2) -> Host-only Adapter (HOSTACCESS, GUI access) --"
"$VBOXMANAGE" modifyvm "$VM_NAME" --nic3 hostonly --hostonlyadapter3 "VirtualBox Host-Only Ethernet Adapter" --cableconnected3 on

echo "-- Adapter 4 (em3) -> soclab-legacy (Metasploitable2) --"
"$VBOXMANAGE" modifyvm "$VM_NAME" --nic4 intnet --intnet4 "soclab-legacy" --cableconnected4 on

echo "-- Adapter 5 (em4) -> soclab-win (Windows 11) — requires CLI, GUI maxes out at 4 adapters --"
"$VBOXMANAGE" modifyvm "$VM_NAME" --nic5 intnet --intnet5 "soclab-win" --cableconnected5 on

echo
echo "== Verifying NIC configuration =="
"$VBOXMANAGE" showvminfo "$VM_NAME" | grep -i "^NIC"

echo
echo "Done. Next steps (manual, inside pfSense):"
echo "  1. Boot pfSense-Gateway"
echo "  2. Console option 1) Assign Interfaces -- confirm em0=WAN, em1=LAN, em2=OPT1, em3=OPT(next), em4=OPT(next)"
echo "  3. Follow docs/01-hypervisor-setup.md from the 'Add Host GUI Access' section onward"
