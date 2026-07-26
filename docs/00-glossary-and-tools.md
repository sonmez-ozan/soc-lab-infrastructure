# Glossary & Tools Reference

Every tool, protocol, and term used across this project. Organized by category.

---

## Virtualization

**VirtualBox** — The hypervisor (virtual machine host software) this entire lab runs on. It lets one physical laptop run several independent "guest" computers (VMs) at once, each with its own virtual CPU, RAM, disk, and network adapters.

**VBoxManage** — VirtualBox's command-line control tool. Used whenever the graphical Settings dialog can't do something — in this project, specifically to add a 5th virtual network adapter to pfSense, since the GUI only exposes 4 adapter tabs. Run from a terminal (Git Bash on Windows), e.g.:
```bash
VBoxManage.exe modifyvm "pfSense-Gateway" --nic5 intnet --intnet5 "soclab-win"
```

**Internal Network** (VirtualBox networking mode) — A private virtual switch that only VMs explicitly attached to the same named network (e.g. `soclab-net`) can see. Chosen for this lab specifically because it never touches the physical home network — even a real "attack" from Kali stays fully contained.

**Host-only Adapter** — A separate VirtualBox networking mode that connects VMs to the physical host machine only (not the internet, not other VMs unless also attached). Used here purely so the laptop's browser can reach pfSense's admin GUI, since the main lab network is deliberately isolated from the host.

**NAT (Network Address Translation)** — The VirtualBox networking mode that gives a VM outbound internet access by routing its traffic through the host's own connection. Used only on pfSense's WAN interface, so the lab can reach the internet for updates without exposing any lab VM directly.

---

## pfSense / Firewall & Routing

**pfSense** — Open-source firewall/router operating system (built on FreeBSD) running as its own VM. It's the single point through which all inter-zone traffic passes, meaning it's the one place that decides what's allowed to talk to what.

**WAN / LAN / OPTx** — pfSense's naming convention for interfaces. `WAN` is always the internet-facing interface. `LAN` is the primary internal interface. Every additional interface pfSense detects gets auto-named `OPT1`, `OPT2`, etc., in the order they were assigned — these were later given human-readable Description labels (e.g. `VICTIMS`, `ATTACKER`) for clarity, but pfSense's internal config still refers to them as `opt1`–`opt6`; only the display label changed.

**Interface Assignment** — The pfSense step (Interfaces → Assignments) where a detected physical/virtual NIC (e.g. `em3`) gets bound to a logical role (e.g. `LEGACY`). Nothing passes traffic on a new NIC until this step is done.

**Default-deny policy** — pfSense's core security model: every interface silently drops all traffic unless an explicit "Pass" rule allows it. This is why a newly-added interface (or a correctly-configured VLAN) can look completely broken even when networking is technically fine — there's just no rule yet permitting the traffic through.

**Firewall Alias** — A named group of IPs/networks (e.g. `Victims_Net` = `10.10.20.0/24`) that firewall rules can reference instead of raw CIDR blocks. Makes rules self-documenting and easier to update in one place.

**Rule ordering** — pfSense evaluates firewall rules top-to-bottom per interface and stops at the first match. A classic mistake (hit during this build) is adding a new, properly-scoped rule *below* an old permissive one — the old rule still wins. Always check the full rule list, not just that a new rule exists.

**Diagnostics → Ping / Packet Capture** — pfSense's built-in tools for testing connectivity and inspecting raw traffic directly from the firewall itself, used throughout this build to prove whether a problem was "traffic never arrived" vs "traffic arrived but wasn't allowed through."

---

## VLANs & Trunking

**VLAN (Virtual LAN, IEEE 802.1Q)** — A way to run multiple logically-separate networks over one shared physical (or virtual) wire, by tagging each frame with a VLAN ID number. Devices only process traffic tagged with a VLAN ID they're configured to handle.

**Trunk** — A single link (here, the VirtualBox Internal Network `soclab-net`) that carries multiple VLANs' tagged traffic simultaneously. Kali and Ubuntu both plug into this same trunk but tag their own traffic as VLAN 30 and VLAN 20 respectively, so pfSense can tell them apart and route accordingly.

**Tagged vs. Untagged** — Tagged traffic carries an explicit VLAN ID in the frame header; untagged (native) traffic has none and is treated as belonging to whatever VLAN a switch/interface treats as its default. In this lab, the Management zone is deliberately left as the native/untagged network on the trunk.

**802.1Q subinterface** (e.g. `eth0.30`, `enp0s3.20`) — The Linux kernel's representation of "the VLAN-30-tagged view of this physical NIC." Created with `ip link add link <parent> name <name> type vlan id <id>`. Requires the `8021q` kernel module to be loaded.

---

## Linux Networking

**netplan** — Ubuntu's modern network configuration system. Reads YAML files under `/etc/netplan/` and generates the actual configuration for whichever backend ("renderer") is active — either `systemd-networkd` or `NetworkManager`. This project hit repeated YAML-schema errors with netplan's `vlans:` key, ultimately resolved by verifying the file was syntactically correct via `netplan generate` and rebuilding it cleanly rather than continuing to hand-edit it.

**ifupdown / `/etc/network/interfaces`** — The older, simpler Debian-style network configuration method, still used by legacy systems like Metasploitable2 (and no longer the default on modern Ubuntu, which is why editing this file had no effect on the Ubuntu-Victim VM — netplan was overriding it).

**rc.local** — A legacy boot script (`/etc/rc.local`) that runs arbitrary shell commands once at startup, before most other services. Used here as a practical workaround to bring up Ubuntu's VLAN interface and route at boot, after netplan's native `vlans:` support proved unreliable in this environment. Must be made executable (`chmod +x`) and enabled via `systemctl enable rc-local`.

**`ip link` / `ip addr` / `ip route`** — The modern Linux commands for, respectively: creating/managing network interfaces, assigning IP addresses to them, and viewing/editing the routing table. Replaces the older `ifconfig`/`route` commands (still present on very old systems like Metasploitable2).

**Default route** — The "if nothing more specific matches, send it here" entry in a routing table. A completely valid, correctly-addressed interface will still fail to get *replies* back out if this is missing — the single bug that explained Ubuntu's VLAN not working even once the interface itself was healthy.

**rp_filter (Reverse Path Filtering)** — A Linux kernel security feature that can drop packets if the reply would go out a different interface than the request arrived on. Check this whenever a host receives a packet but never replies — in this project the cause turned out to be a missing default route, not rp_filter.

**tcpdump** — A packet capture tool used to see, in real time, exactly what traffic is arriving on an interface — including VLAN tags. Was the deciding piece of evidence that Ubuntu's VLAN tagging itself was working correctly (tagged frames were arriving) even while ping still failed for an unrelated reason (missing route).

**ethtool** — Used to inspect/toggle network interface driver features, including VLAN offloading, which on some emulated NICs can silently strip or mishandle VLAN tags at the hardware/driver level.

---

## WireGuard VPN

**WireGuard** — A modern, lightweight VPN protocol. Unlike older VPNs, it uses only UDP (no TCP mode exists), a fixed pair of public/private keys per device instead of certificates, and is designed to be simple enough to audit.

**Tunnel / Peer** — A WireGuard "tunnel" is the local endpoint's configuration (its own keypair, listen port, internal tunnel IP). A "peer" is each remote party allowed to connect — configured with the peer's public key and which IPs they're allowed to send from (`AllowedIPs`).

**Handshake** — The initial cryptographic exchange that establishes a WireGuard session. "Latest Handshake: never" means the two ends have never successfully authenticated to each other yet, even if packets are visibly being sent.

---

## Windows Networking

**RDP (Remote Desktop Protocol)** — Microsoft's protocol for remotely viewing/controlling a Windows desktop, used here to access the Windows 11 victim VM from Kali (`xfreerdp`).

**Network Profile (Private/Public)** — Windows classifies each network connection as Domain, Private, or Public, and applies different default firewall strictness to each. A connection incorrectly left as "Public" was one cause of blocked traffic during this build, fixed via `Set-NetConnectionProfile`.

**Firewall Rule Scope** — Windows Firewall rules can be scoped to "Local subnet only" or "Any IP address." The default "Local subnet" scope silently blocks traffic from a different zone's subnet (like Kali's) even when the rule itself is enabled — this was the cause of an RDP/ping failure that looked like a missing rule.

---

## Testing / Diagnostic Tools

**ping (ICMP Echo)** — Sends a small "are you there" packet and waits for a reply. The most basic connectivity test used throughout this project — and also a source of a false negative, since a host pinging its *own* gateway or its *own* tunnel interface can behave differently than real host-to-host traffic.

**TTL (Time To Live)** — A field in every IP packet that decreases by 1 each time it passes through a router. Seeing a reply's TTL drop by exactly 1 (e.g. 64 → 63) confirms traffic routed through a hop (pfSense) rather than staying on one local segment — used in this project to confirm cross-VLAN routing was actually happening, not just that both hosts reached the same gateway.

**nmap** — A port/service scanner, used here to confirm a specific service (RDP on port 3389) was actually open and reachable from the attacker zone, beyond just basic ping connectivity.

---

## Project / Documentation Terms

**ADR (Architecture Decision Record)** — A short document capturing one specific design decision: the context that led to it, the decision itself, and its consequences/trade-offs. Never edited after the fact — if a decision is later reversed, a new ADR is written and the old one is marked "Superseded," preserving the actual decision history rather than rewriting it.

**Zone** — This project's term for a network segment with a distinct trust level and IP range (Management, Victims, Attacker, Legacy, Windows), each with its own pfSense interface and firewall policy.
