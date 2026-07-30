# Network Design

## Design Goals

1. Fully isolate lab traffic — including live "attacks" from Kali — from the home network.
2. Segment the lab itself into trust zones (Management, Victims, Attacker, Legacy, Windows), enforced by firewall policy, not just naming.
3. Demonstrate real VLAN tagging where the guest OS supports it, and a legitimate dedicated-NIC fallback where it doesn't.
4. Allow secure remote administration without exposing the firewall GUI to the open internet.

## Final Architecture

![Network Topology](../diagrams/network-topology.png)

| Zone | pfSense Interface | Underlying Port | VirtualBox Network | Subnet | Gateway | Tagged? |
|---|---|---|---|---|---|---|
| Management | LAN | em1 | soclab-net (native) | 10.10.10.0/24 | 10.10.10.1 | No |
| Host Access | HOSTACCESS | em2 | Host-only (vboxnet0) | 192.168.56.0/24 | 192.168.56.10 | N/A |
| WireGuard VPN | WIREGUARDNET | tun_wg0 | — | 10.10.99.0/24 | 10.10.99.1 | N/A |
| Victims | VICTIMS | em1.20 | soclab-net (VLAN 20) | 10.10.20.0/24 | 10.10.20.1 | Yes |
| Attacker | ATTACKER | em1.30 | soclab-net (VLAN 30) | 10.10.30.0/24 | 10.10.30.1 | Yes |
| Legacy | LEGACY | em3 | soclab-legacy | 10.10.40.0/24 | 10.10.40.1 | No |
| Windows | WIN | em4 | soclab-win | 10.10.50.0/24 | 10.10.50.1 | No |

**Interface naming note:** pfSense auto-assigns interfaces as OPT1, OPT2, etc. All were renamed via their Description field to the clean zone names above. This only changes the display label — the underlying pfSense config still references `opt1`–`opt6` internally. WireGuard's interface was specifically named `WIREGUARDNET` rather than `WIREGUARD` to avoid colliding with the name of the WireGuard package's own menu tab.

**Why Management has no VLAN tag:** an initial design tagged Management as VLAN 10, but pfSense rejected this because the physical LAN interface already held the `10.10.10.1/24` address from initial setup. Rather than force a redundant tagged interface, the existing native/untagged LAN interface was kept as the Management zone directly — a standard, valid pattern (native network as the trusted/management segment, additional VLANs layered on top for everything else). See [ADR-001](04-adr/001-drop-management-vlan.md).

## Why Some Zones Are VLAN-Tagged and Some Are Dedicated NICs

| Host | Method | Why |
|---|---|---|
| Kali-Attacker | VLAN 30 tag (in-guest) | Modern Linux, full `8021q` support |
| Ubuntu-Victim | VLAN 20 tag (in-guest) | Modern Linux, full `8021q` support |
| Metasploitable2 | Dedicated NIC (soclab-legacy) | Ubuntu 8.04-based; VLAN tooling (`vconfig`) unavailable and its package repos are dead — cannot install `8021q` support through any normal channel |
| Windows 11 | Dedicated NIC (soclab-win) | VirtualBox's emulated Intel PRO/1000 NIC driver exposes a "Priority & VLAN" on/off toggle but no field to set an actual VLAN ID — a driver limitation, not a missing configuration step |

Both non-taggable hosts get the same treatment: their own dedicated, untagged VirtualBox Internal Network, wired to its own pfSense interface, with the same zone-based firewall policy applied as the tagged VLANs. See [ADR-002](04-adr/002-vlan-tagging-vs-separate-networks.md) and [ADR-003](04-adr/003-legacy-and-windows-zones-for-non-taggable-hosts.md).

**A hardware note on adding a 5th zone:** VirtualBox's Settings GUI only exposes 4 network adapter tabs per VM. Since pfSense needed a 5th (for the Windows zone), it was added via the command line instead:
```bash
VBoxManage.exe modifyvm "pfSense-Gateway" --nic5 intnet --intnet5 "soclab-win" --cableconnected5 on
```
The adapter is fully functional even though it never appears in the GUI dialog — all future changes to it must go through `VBoxManage`.

## Firewall Policy (Inter-Zone Rules)

Aliases used: `Management_Net` = `10.10.10.0/24`, `Victims_Net` = `10.10.20.0/24`, `Attacker_Net` = `10.10.30.0/24`.

| Interface | Source | Destination | Purpose |
|---|---|---|---|
| ATTACKER | Attacker_Net | Victims_Net | Allow Attacker to reach Victims |
| ATTACKER | Attacker_Net | 10.10.40.0/24 | Allow Attacker to reach Legacy zone |
| ATTACKER | Attacker_Net | 10.10.50.0/24 | Allow Attacker to reach Windows zone |
| VICTIMS | 10.10.20.0/24 | any | Allow Victims outbound |
| LEGACY | 10.10.40.0/24 | any | Allow Legacy outbound |
| LEGACY | 10.10.40.0/24 | 10.10.20.0/24 | Allow Legacy to reach Victims |
| WIN | 10.10.50.0/24 | any | Allow Windows zone outbound |
| WIN | 10.10.50.0/24 | 10.10.20.0/24 | Allow Windows zone to reach Victims |
| HOSTACCESS | 192.168.56.1 | 192.168.56.10 | Host → pfSense GUI (HTTPS) + ping |
| HOSTACCESS | any | this firewall, UDP/51820 | Allow WireGuard handshakes |

**Policy summary:** Attacker can reach every other zone (to simulate attacks). Victims can reach out but nothing can reach *in* to Victims except Attacker, Legacy, and Windows explicitly. Nothing reaches Attacker from any other zone — pfSense's default-deny handles this with no explicit rule needed. This asymmetry was verified directly (see [Testing](02-testing.md), Test 4).

**A rule-ordering lesson learned:** when tightening an initially permissive Attacker rule, a new properly-scoped rule was added *below* the old permissive one — since pfSense matches top-to-bottom and stops at first match, the old rule kept winning until it was explicitly deleted. Always review the full rule list after editing, not just confirm the new rule exists.

## Remote Access — WireGuard VPN

A WireGuard tunnel (`WIREGUARDNET`, 10.10.99.0/24) lets an administrator manage the lab remotely without exposing pfSense's web GUI to the internet. Full setup and troubleshooting: [Lessons Learned — WireGuard self-ping mystery](05-lessons-learned.md#wireguard-self-ping).
