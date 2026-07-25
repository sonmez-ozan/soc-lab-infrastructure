# Installing & Configuring Metasploitable2-Victim

**Status: ✅ Working, persistent across reboot.**

## 1. Download & Import

Downloaded `Metasploitable2-Linux.zip` from SourceForge. Extracted to get a `.vmdk` disk plus a `.vmx` file (VMware format, not native VirtualBox).

VM creation: `Machine → New`, leave ISO Image unselected, choose **"Use an Existing Virtual Hard Disk File"**, point to the extracted `Metasploitable.vmdk` (~8.00 GB — double check this against VirtualBox's disk dropdown, which can default to an unrelated cached disk if one exists).

- 512 MB RAM (sufficient for this VM's age/footprint)
- Login: `msfadmin` / `msfadmin` (intentionally weak by design — this VM exists to be attacked)

## 2. Why It Can't Do VLAN Tagging

Metasploitable2 is built on Ubuntu 8.04 ("hardy"), whose package repositories are long dead. `apt-get update` returns repeated 404s, and even when the `vlan` package's metadata is found, the actual `.deb` can't be downloaded. `vconfig` and `lsmod | grep 8021q` both confirm no VLAN tooling exists and none can be installed through normal channels.

**Decision:** rather than force a workaround, this was treated as a legitimate real-world constraint and given its own dedicated, untagged zone instead. See [ADR-007](../adr/007-vlan-tagging-vs-separate-networks.md).

## 3. Network Adapter

- Adapter 1: Internal Network, `soclab-legacy` (dedicated, not the shared `soclab-net` trunk)

## 4. Persistent IP Configuration

Metasploitable2 uses the older `ifupdown` system (`/etc/network/interfaces` genuinely works here, unlike on modern Ubuntu):

```bash
sudo nano /etc/network/interfaces
```

```
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 10.10.40.10
    netmask 255.255.255.0
    gateway 10.10.40.1
```

> **Note on indentation:** any consistent leading whitespace works (tabs or spaces) — if your terminal can't type a tab (e.g. over some VirtualBox console setups), a few spaces is equally valid. `auto`/`iface` lines themselves must be flush left with no leading space.

```bash
sudo /etc/init.d/networking restart
ip addr show eth0
```

(`SIOCDELRT: No such process` during the restart is harmless — it's just the script trying to delete a route that didn't exist yet.)

## 5. Verify & Confirm Persistence

From Kali: `ping -c 4 10.10.40.10` — expect 0% loss.

```bash
sudo reboot
```

After reboot: `ip addr show eth0` and `ip route` should already show `10.10.40.10/24` and a default route via `10.10.40.1`, with zero manual steps.

## Verified Connectivity

| From | Result |
|---|---|
| Kali → Metasploitable2 | ✅ 0% loss, TTL=63 (routed through pfSense) |
| Ubuntu-Victim → Metasploitable2 | ✅ correctly denied — no rule permits Victims → Legacy |
