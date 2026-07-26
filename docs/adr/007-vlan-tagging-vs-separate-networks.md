# ADR-007: In-Guest VLAN Tagging for Kali/Ubuntu, Instead of Separate Networks for Everyone

**Status:** Accepted

## Context

Two options existed for segmenting the Attacker and Victims zones:

- **Option A:** attach each VM to one shared trunk (`soclab-net`) and have the guest OS itself tag its traffic with the appropriate VLAN ID (802.1Q), matching how real managed switches/servers commonly segment traffic.
- **Option B:** give every zone its own separate, untagged VirtualBox Internal Network, with pfSense using one dedicated NIC per zone instead of VLAN tags on a shared interface.

Option B is simpler to set up and debug for a beginner, but doesn't demonstrate real VLAN tagging skills, and doesn't scale — every additional zone needs its own physical/virtual NIC on both the VM and the router, and VirtualBox's GUI only exposes 4 NIC slots per VM.

## Decision

Use in-guest VLAN tagging (Option A) for hosts capable of it — Kali-Attacker and Ubuntu-Victim, both modern Linux with full `8021q` kernel module support. Reserve dedicated networks (Option B) only for hosts that genuinely cannot tag their own traffic (see [ADR-008](008-legacy-and-windows-zones-for-non-taggable-hosts.md)).

## Consequences

- Demonstrates a transferable, real networking skill (VLAN subinterfaces, trunk design) rather than avoiding it.
- Required real troubleshooting to get working correctly on Ubuntu specifically — see [Lessons Learned](../05-lessons-learned.md#the-ubuntu-vlan-saga).
- Scales better: adding another modern-Linux zone in the future doesn't require another VirtualBox NIC or another `VBoxManage` workaround.
