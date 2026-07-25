# ADR-001: Use VirtualBox Internal Network Instead of Bridged Networking

**Status:** Accepted

## Context

VirtualBox offers several networking modes for VM adapters, most notably **Bridged** (VM appears as a real device on the physical home network) and **Internal Network** (a private virtual switch visible only to VMs explicitly attached to it).

This lab intentionally includes an attacker VM (Kali) running real scanning/exploitation tooling against deliberately vulnerable targets (Metasploitable2, an intentionally-weak Windows config). If any of this traffic reached the physical home network, it could affect other real devices on that network.

## Decision

Use VirtualBox **Internal Network** (`soclab-net`, `soclab-legacy`, `soclab-win`) for all lab-internal traffic. Only pfSense's WAN interface uses NAT, purely for outbound internet access (package updates, downloads) — no lab VM is ever bridged onto the physical network directly.

## Consequences

- The lab is fully contained — even a real, successful "attack" from Kali cannot leave the virtual environment.
- Host GUI access to pfSense required an extra dedicated Host-only interface (`HOSTACCESS`), since the isolated LAN segment isn't reachable from the host by design.
- Remote access to the lab (outside the host machine) requires the WireGuard VPN tunnel rather than simple bridged-network reachability.
