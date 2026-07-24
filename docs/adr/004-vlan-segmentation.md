# ADR 004: Segment the lab network into VLANs

## Status
Accepted

## Context
The initial design placed all lab VMs on a single flat `10.10.10.0/24`
network. This does not reflect how real enterprise networks isolate
management, user/target, and untrusted zones from each other, and it
allows any VM to freely reach any other VM regardless of role.

## Decision
Split the lab LAN into three VLANs, tagged on pfSense's single LAN
interface (`em1`):
- VLAN 10 (Management) — 10.10.10.0/24
- VLAN 20 (Victims/Targets) — 10.10.20.0/24
- VLAN 30 (Attacker) — 10.10.30.0/24

pfSense enforces firewall rules between VLANs (e.g. Attacker -> Victims
allowed, Victims -> Attacker denied).

## Consequences
- More realistic network design, closer to enterprise segmentation
  practices
- Requires reconfiguring IP addressing for any VM built before this
  decision
- Adds firewall rule complexity, but this is intentional — it's a core
  part of what the lab is meant to teach and demonstrate