# Network Design

## Overview
This lab uses a segmented internal network behind a pfSense gateway/firewall.
Traffic between segments (VLANs) is explicitly controlled by firewall rules,
mirroring how real enterprise networks isolate management, user, and
untrusted zones from each other.

## VLAN Segmentation

| VLAN | Purpose         | Subnet          | Gateway IP     |
|------|-----------------|-----------------|----------------|
| 10   | Management      | 10.10.10.0/24   | 10.10.10.1     |
| 20   | Victims/Targets | 10.10.20.0/24   | 10.10.20.1     |
| 30   | Attacker        | 10.10.30.0/24   | 10.10.30.1     |

All VLANs are tagged on pfSense's single LAN interface (em1), which is
attached to the VirtualBox Internal Network `soclab-net`. VirtualBox passes
tagged VLAN traffic through transparently; pfSense handles all tagging,
routing, and inter-VLAN firewall rules.

## VM Inventory

| VM               | VLAN | Role                                | IP            |
|------------------|------|-------------------------------------|---------------|
| pfSense           | 10/20/30 | Gateway / firewall / router    | .1 on each    |
| Wazuh Manager     | 10 (Mgmt)| SIEM server (future project)   | 10.10.10.10   |
| Windows 11 Victim | 20   | Endpoint target                    | 10.10.20.20   |
| Ubuntu Victim     | 20   | Endpoint target                    | 10.10.20.21   |
| Metasploitable2   | 20   | Deliberately vulnerable target     | 10.10.20.22   |
| Kali Linux        | 30   | Attacker box                       | 10.10.30.100  |

## Inter-VLAN Firewall Policy

- **Attacker (30) -> Victims (20):** allowed (this is the whole point — Kali
  needs to reach targets to simulate attacks)
- **Victims (20) -> Attacker (30):** denied (targets should never initiate
  connections back to the attacker)
- **Management (10) <-> Victims/Attacker:** allowed one-way in for monitoring
  (agents reporting to Wazuh) once that project is built; tightened further
  at that point
- **Default:** deny all, explicitly allow only what's needed (least privilege)

## Remote Access
A WireGuard VPN is configured on pfSense to allow secure remote management
of the lab without exposing the web GUI directly to the host network.

## Design Decisions
See `/docs/adr/` for detailed reasoning behind key architecture choices.