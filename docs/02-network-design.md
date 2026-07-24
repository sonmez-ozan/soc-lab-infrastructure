# Network Design

## Overview
This lab uses an isolated internal network to safely run attack simulations
without touching the host machine's home network. pfSense acts as the
gateway/firewall for the segment, routing outbound traffic via NAT while
keeping all lab-internal traffic contained.

## Network Segment
- **Subnet:** 10.10.10.0/24
- **VirtualBox network type:** Internal Network (isolated from host LAN)
- **Gateway:** pfSense (10.10.10.1)

## VM Inventory

| VM               | Role                               | RAM  | IP            |
|------------------|------------------------------------|------|---------------|
| pfSense          | Gateway / firewall                 | 1GB  | 10.10.10.1    |
| Wazuh Manager    | SIEM server (Ubuntu Server)        | 6GB  | 10.10.10.10   |
| Suricata Sensor  | NIDS                               | 2GB  | 10.10.10.11   |
| Windows 11 Victim| Endpoint (Sysmon + Wazuh agent)    | 4GB  | 10.10.10.20   |
| Ubuntu Victim    | Endpoint (Wazuh agent)             | 2GB  | 10.10.10.21   |
| Metasploitable2  | Deliberately vulnerable target     | 1GB  | 10.10.10.22   |
| Kali Linux       | Attacker box                       | 4GB  | 10.10.10.100  |

## Design Decisions
- **Metasploitable2 chosen over Metasploitable3 initially** — M2 is a
  pre-built VM (fast setup), letting early focus stay on the detection
  pipeline (Suricata/Wazuh visibility) rather than target provisioning.
  Metasploitable3 (Windows variant) is planned as a later addition once
  the core lab is stable, for more modern attack simulation (e.g. EternalBlue).
- **Internal Network over Bridged/NAT Network** — keeps lab traffic fully
  isolated from the home network, since Kali will be actively attacking
  other lab VMs.
- **Static IPs across the board** — simplifies Suricata/Wazuh rule writing
  and makes logs easier to read while learning.

## Diagram
See `/diagrams/network-topology.png`