# Installing & Configuring pfSense-Gateway

## 1. Download

pfSense downloads go through the Netgate store checkout (free, requires creating a free Netgate account) rather than a direct link. Choose image type **AMD64 ISO IPMI/Virtual Machines** — the "Memstick USB" options are for flashing physical hardware, not for VirtualBox. Download arrives as `.gz`; extract to get the `.iso`.

> Considered [OPNsense](https://opnsense.org) as a no-account alternative (same FreeBSD/`pf` foundation) — pfSense CE was kept for its larger install base and tutorial availability. See [ADR](../adr/) for full reasoning if included.

## 2. Create the VM

| Setting | Value |
|---|---|
| Name | `pfSense-Gateway` |
| Type / Version | BSD / FreeBSD (64-bit) |
| Memory | 1024 MB |
| CPUs | 1 |
| Disk | 8 GB, VDI, dynamically allocated |
| Unattended Installation | Left unchecked (manual install) |

**Gotcha:** if the "Finish" button in VM creation appears unresponsive, check whether the Name field has a red border — this means a VM with that name already exists from a prior attempt. Check the main VM list before renaming; it may already be created.

## 3. Network Adapters (before first boot)

| Adapter | Attached To | Purpose |
|---|---|---|
| 1 | NAT | WAN — internet via host NAT |
| 2 | Internal Network: `soclab-net` | LAN — isolated lab segment |
| 3 | Host-only Adapter | Host GUI access (added post-install, see below) |
| 4 | Internal Network: `soclab-legacy` | Legacy zone (added later) |
| 5 | Internal Network: `soclab-win` (via `VBoxManage`, GUI can't add a 5th) | Windows zone (added later) |

## 4. Install Walkthrough

- License → Accept
- Software: pfSense CE (current stable at build time)
- Keymap: default (US)
- Partition scheme: ZFS, Stripe — No Redundancy (single disk) — see [ADR-003](../adr/003-zfs-over-ufs.md) for the ZFS-vs-UFS reasoning
- Disk: select the single virtual disk, confirm, format
- **Before rebooting:** manually eject the ISO (Devices → Optical Drives → Remove Disk From Virtual Drive), or it will boot back into the installer

## 5. Interface Assignment (critical first-boot step)

pfSense must be told which detected NIC is WAN vs LAN. Match by MAC/order, not assumption:

| Interface | Matches VirtualBox Adapter | Role |
|---|---|---|
| em0 | Adapter 1 (NAT) | WAN |
| em1 | Adapter 2 (soclab-net) | LAN |

Use console option **1) Assign Interfaces**. Configure LAN as Static IPv4 `10.10.10.1/24`, gateway none (correct for a LAN-type interface).

**Console UX gotcha:** "Press <ENTER> for none" prompts require an actual blank Enter — typing the literal word "none" causes an infinite re-prompt loop.

## 6. Add Host GUI Access (HOSTACCESS / OPT1)

The LAN segment is intentionally isolated from the host, so the GUI isn't reachable there. Add a dedicated host-only interface:

1. VM Settings → Network → Adapter 3 → Enabled, Attached to **Host-only Adapter**
2. Console → option 1) Assign Interfaces → re-assign all three explicitly: WAN=em0, LAN=em1, OPT1=em2
3. Console → option 2) Set interface IP address → OPT1 → Static IPv4 `192.168.56.10/24`, no gateway, DHCP client=no, keep HTTPS enabled

**First access will likely fail** ("took too long to respond," not "connection refused") — this is expected. A brand-new OPT interface gets zero firewall rules by default and silently drops everything, including ICMP. Temporary bootstrap fix via console shell (option 8):

```bash
easyrule pass opt1 tcp 192.168.56.1 192.168.56.10 443
easyrule pass opt1 icmp 192.168.56.1 192.168.56.10
exit
```

If GUI login then fails with "Username or Password incorrect," use console option **3) Reset admin account and password**.

## 7. VLANs (Victims / Attacker)

Interfaces → Assignments → VLANs tab → Add, parent interface `em1`:
- Tag 20 → Victims
- Tag 30 → Attacker

Then Interfaces → Assignments → Interface Assignments: add both as new interfaces, then configure each:
- **VICTIMS**: Static IPv4 `10.10.20.1/24`, no gateway
- **ATTACKER**: Static IPv4 `10.10.30.1/24`, no gateway

> An initial VLAN 10 "Management" interface was rejected with an IP-overlap error against the existing LAN — see [Network Design](../01-network-design.md) for why the native LAN was kept as Management instead.

## 8. Legacy Zone (5th NIC via CLI is not needed here — 4th adapter works)

1. Shut down pfSense
2. Add a new adapter attached to a new Internal Network `soclab-legacy` — **verify the VirtualBox adapter slot number carefully** (see [Lessons Learned](../05-lessons-learned.md) for the mis-assignment incident this caused)
3. Boot pfSense, Interfaces → Assignments, assign the new NIC (`em3`), name it **LEGACY**, Static IPv4 `10.10.40.1/24`

## 9. Windows Zone (5th NIC via VBoxManage — required, GUI maxes out at 4)

```bash
VBoxManage.exe modifyvm "pfSense-Gateway" --nic5 intnet --intnet5 "soclab-win" --cableconnected5 on
VBoxManage.exe showvminfo "pfSense-Gateway" | grep -i nic   # verify
```

Boot pfSense, Interfaces → Assignments, assign the new NIC (`em4`), name it **WIN**, Static IPv4 `10.10.50.1/24`.

## 10. Firewall Aliases & Rules

See [Network Design → Firewall Policy](../01-network-design.md#firewall-policy-inter-zone-rules) for the full alias and rule table to replicate.

## 11. WireGuard VPN Package

System → Package Manager → Available Packages → search "wireguard" → Install. Then VPN → WireGuard:

| Setting | Value |
|---|---|
| Tunnel name | `tun_wg0` |
| Listen Port | 51820 |
| Interface Address | `10.10.99.1/24` |
| Peer Allowed IPs | `10.10.99.2/32` |
| Peer Public Key | (from the **client's** generated keypair — pfSense does not generate the peer's key) |

Add a firewall rule on the interface receiving WireGuard traffic (HOSTACCESS in this build): Protocol UDP, Destination = This Firewall, Port 51820.

Full troubleshooting story for the handshake issues hit here: [Lessons Learned](../05-lessons-learned.md#wireguard-self-ping).
