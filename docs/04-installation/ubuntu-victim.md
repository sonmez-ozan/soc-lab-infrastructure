# Installing & Configuring Ubuntu-Victim

**Status: ✅ Working, persistent across reboot** (this was the hardest-won fix in the whole project — see [Testing, Test 7](../02-testing.md#test-7--ubuntu-vlan-persistence-fix-this-session) and [Lessons Learned](../05-lessons-learned.md#the-ubuntu-vlan-saga) for the full story).

## 1. VM Creation

- Ubuntu Server LTS (chosen over Desktop — lighter weight, headless, more realistic as an endpoint/service target)
- 2048 MB RAM, 20 GB disk
- Network adapter: Internal Network, `soclab-net` (same trunk as Kali)
- Unattended Installation left unchecked — walked through manually
- Install-time network screen: left on DHCP for the install itself (results in an untagged Management-subnet address, e.g. `10.10.10.151`, same expected pattern as Kali)
- Enabled "Install OpenSSH server" + "Allow password authentication over SSH" (no key configured, so password auth needed to avoid lockout)
- Featured Server Snaps: left unselected — unnecessary attack surface for a lightweight target
- After first reboot: remove the ISO from Devices → Optical Drives before continuing, or it reboots into the installer again

## 2. Identify the Interface

Confirm via the login banner or `ip a` — typically `enp0s3` for this VirtualBox NIC type.

## 3. VLAN 20 Tagging (the part that took real troubleshooting)

Modern Ubuntu (Server or Desktop) uses **netplan**, not the older `/etc/network/interfaces` file — editing that file directly does nothing, since netplan overrides it. This project's netplan attempts repeatedly hit "unknown key" schema errors on the `vlans:` section across several different structures tried. Rather than keep fighting netplan, the working, reliable solution used here is `/etc/rc.local` — a startup script that runs the VLAN commands directly at boot.

```bash
sudo apt update && sudo apt install -y vlan
sudo modprobe 8021q
```

Create `/etc/rc.local`:

```bash
sudo nano /etc/rc.local
```

```bash
#!/bin/bash
modprobe 8021q
ip link add link enp0s3 name enp0s3.20 type vlan id 20
ip addr add 10.10.20.10/24 dev enp0s3.20
ip link set enp0s3.20 up
ip route add default via 10.10.20.1 dev enp0s3.20 metric 50
exit 0
```

```bash
sudo chmod +x /etc/rc.local
sudo systemctl enable rc-local
sudo systemctl start rc-local
```

**Two bugs came up while building this file:**

1. **Typo silently breaking address assignment.** An early draft had `enp0s.20` (missing the `3`) on the `ip addr add` line while the `ip link add` line correctly said `enp0s3.20`. Result: the VLAN interface got created, but its IP was never actually assigned, and boot logs showed `Cannot find device "enp0s.20"`. Always double-check every line references the exact same interface name — not just the first one.

2. **Missing default route.** Even after the interface came up correctly with the right IP, ping to the gateway still failed. `tcpdump -i enp0s3 -e -n vlan 20` proved tagged frames *were* arriving — ruling out VirtualBox/trunk/tagging entirely — but `ip route` showed only the auto-created connected route, no default route. Ubuntu could receive pings but had nowhere to send replies. Fixed by adding the `ip route add default ...` line above. The `metric 50` pins this route explicitly ahead of a coexisting DHCP-assigned default route that the untagged parent interface (`enp0s3`) also picks up from the trunk's native VLAN.

## 4. Verify

```bash
ip addr show enp0s3.20
ip route
```

Expected: `enp0s3.20` state `UP` with `10.10.20.10/24`, and `default via 10.10.20.1 dev enp0s3.20 metric 50` at the top of the route table.

From Kali: `ping -c 4 10.10.20.10` should show 0% loss.

## 5. Confirm Persistence

```bash
sudo reboot
```

After reboot, without touching anything: `ip addr show enp0s3.20` and `ip route` should show the interface and route already in place, and the Kali ping should succeed immediately.
