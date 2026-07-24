# Network Design

## Overview
This lab uses a segmented internal network behind a pfSense gateway/firewall.
Traffic between segments (VLANs) is explicitly controlled by firewall rules,
mirroring how real enterprise networks isolate management, user, and
untrusted zones from each other.

## Network Segmentation

| Zone       | Interface       | Subnet          | Gateway IP    | Tagged? |
|------------|------------------|-----------------|---------------|---------|
| Management | LAN (em1)        | 10.10.10.0/24   | 10.10.10.1    | No (native/untagged) |
| Victims    | OPT3 (VLAN 20 on em1) | 10.10.20.0/24 | 10.10.20.1  | Yes (VLAN 20) |
| Attacker   | OPT4 (VLAN 30 on em1) | 10.10.30.0/24 | 10.10.30.1  | Yes (VLAN 30) |
| Host Access| OPT1 (em2)       | 192.168.56.0/24 | 192.168.56.10 | N/A (host-only, GUI access) |

The Management zone uses the native (untagged) LAN interface rather than a
separate tagged VLAN — this is a common pattern where the untagged network
serves as management/trusted, while additional VLANs are layered on top for
other zones. See ADR 004 for the reasoning behind segmentation, and the
troubleshooting notes below for why Management isn't its own tagged VLAN.

All VLANs are tagged on pfSense's single LAN interface (em1), which is
attached to the VirtualBox Internal Network `soclab-net`. VirtualBox passes
tagged VLAN traffic through transparently; pfSense handles all tagging,
routing, and inter-VLAN firewall rules.

## VM Inventory

| VM                | Zone       | Role                              | IP            |
|-------------------|------------|-------------------------------------|---------------|
| pfSense            | Gateway    | Firewall / router for all zones    | .1 on each zone |
| Wazuh Manager      | Management | SIEM server (future project)       | 10.10.10.10   |
| Windows 11 Victim  | Victims    | Endpoint target                    | 10.10.20.20   |
| Ubuntu Victim      | Victims    | Endpoint target                    | 10.10.20.21   |
| Metasploitable2    | Victims    | Deliberately vulnerable target     | 10.10.20.22   |
| Kali Linux         | Attacker   | Attacker box                       | 10.10.30.100  |

## Inter-Zone Firewall Policy

- **Attacker -> Victims:** allowed (Kali needs to reach targets to simulate
  attacks)
- **Victims -> Attacker:** denied (targets should never initiate
  connections back to the attacker)
- **Management <-> Victims/Attacker:** allowed one-way in for monitoring
  (agents reporting to Wazuh) once that project is built; tightened further
  at that point
- **Default:** deny all, explicitly allow only what's needed (least privilege)

## Remote Access
A WireGuard VPN is configured on pfSense to allow secure remote management
of the lab without exposing the web GUI directly to the host network.

### Status
WireGuard is fully configured on pfSense (tunnel, peer, keys, firewall
rule on OPT1). Initial connectivity testing from the host machine over
VirtualBox's Host-Only adapter did not complete a handshake, despite
firewall rules, keys, and clock sync all being verified correct. This is
suspected to be a VirtualBox Host-Only UDP hairpin routing limitation
(host and VM on the same physical machine), which is a known category of
issue distinct from a genuinely external client. Full validation is
planned once a lab VM or external device is available to test from.

## Design Decisions
See `/docs/adr/` for detailed reasoning behind key architecture choices,
including why VLAN 10 (originally planned as a separate tagged Management
VLAN) was dropped in favor of using the native LAN interface directly —
this avoided an IP conflict with the existing LAN configuration and is a
valid, common real-world pattern.