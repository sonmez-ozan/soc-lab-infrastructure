# ADR-008: Dedicated Untagged Zones for Metasploitable2 and Windows 11

**Status:** Accepted

## Context

Two planned VMs turned out to be unable to perform in-guest VLAN tagging, for two entirely different reasons:

- **Metasploitable2** is based on Ubuntu 8.04 ("hardy"). Its package repositories are dead — `apt-get install vlan` fails with repeated 404 errors, and `vconfig`/the `8021q` module cannot be installed through any normal channel.
- **Windows 11**, running VirtualBox's emulated Intel PRO/1000 MT Desktop NIC driver, exposes a "Priority & VLAN" toggle in Advanced adapter properties, but no field to actually enter a VLAN ID. Confirmed via `Get-NetAdapterAdvancedProperty` in PowerShell — no VLAN ID property exists for this driver at all. Unlike Linux, Windows relies on the NIC driver itself to perform 802.1Q tagging; there's no OS-level equivalent to `ip link add ... type vlan`.

## Decision

Give both hosts their own dedicated, untagged VirtualBox Internal Network (`soclab-legacy` and `soclab-win` respectively), each wired to its own dedicated pfSense NIC (`em3`/LEGACY and `em4`/WIN), with the same zone-based firewall policy enforced as the tagged VLANs.

## Consequences

- Requires additional physical/virtual NICs on the pfSense VM — the 5th (`soclab-win`) had to be added via `VBoxManage` CLI since VirtualBox's Settings GUI only exposes 4 adapter tabs.
- This is a legitimate, common real-world pattern: infrastructure that can't participate in modern VLAN tagging (old legacy systems, certain driver/hardware limitations) gets isolated at the switch/firewall level with a dedicated port instead of forcing an unsupported feature at the endpoint.
- Both zones still get the same firewall-enforced isolation as the tagged VLANs — the mechanism differs, the security policy doesn't.
