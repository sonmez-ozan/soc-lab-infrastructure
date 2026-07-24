# ADR 001: Use Internal Network instead of Bridged Network

## Status
Accepted

## Context
The lab needs Kali Linux to actively attack other VMs (Metasploitable2,
Windows/Ubuntu victims). This traffic must never reach the home network,
both for safety and to avoid any legal/ethical issues with scanning or
attacking devices outside the lab.

## Decision
Use VirtualBox's "Internal Network" type (named `soclab-net`) for all lab
VMs, rather than "Bridged Adapter" (which would place VMs directly on the
home LAN) or "NAT Network" (which still routes toward the host's network
stack more directly than desired).

## Consequences
- Lab traffic is fully isolated from the home network by default
- VMs on `soclab-net` have no external connectivity unless routed through
  pfSense, so a gateway VM is required for internet access (updates, etc.)
- Slightly more setup complexity than Bridged, but the isolation is worth
  it for a lab designed to run real attack simulations