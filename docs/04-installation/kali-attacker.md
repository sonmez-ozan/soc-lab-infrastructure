# Installing & Configuring Kali-Attacker

**Status: ✅ Working, persistent across reboot.**

## 1. Download & Import

Downloaded from [kali.org/get-kali](https://www.kali.org/get-kali/) → Virtual Machines → VirtualBox, 64-bit — arrives as a `.7z` containing a native `.vbox` + `.vdi` pair, **not** an OVF/OVA appliance.

**Import method matters here:** VirtualBox's `File → Import Appliance` only accepts `.ovf`/`.ova` files, so it's the wrong tool for this download. Use `Machine → Add...` instead, and browse directly to the `.vbox` file — this registers the existing VM without needing any conversion.

Renamed from the default `kali-linux-...-virtualbox-amd64` to `Kali-Attacker` to match the lab's naming convention.

## 2. Network Adapter

- Adapter 1: Internal Network, name `soclab-net` (the shared VLAN trunk)

On first boot, Kali gets an untagged DHCP address on the Management subnet (e.g. `10.10.10.150/24`) — this confirms the adapter attachment is correct, but no VLAN tag is applied yet.

## 3. VLAN 30 Tagging

Identify the interface name first: `ip a` (typically `eth0`).

```bash
sudo ip link add link eth0 name eth0.30 type vlan id 30
sudo ip addr add 10.10.30.10/24 dev eth0.30
sudo ip link set eth0.30 up
sudo ip route add default via 10.10.30.1
```

If ping to the gateway fails at this point with a correctly-addressed, `UP` interface — check the pfSense firewall log before assuming the VLAN itself is broken. In this build the cause was simply a missing Pass rule (pfSense's default-deny), not a tagging problem.

## 4. Persistent Config — `/etc/network/interfaces`

Kali still uses the older `ifupdown` system (unlike modern Ubuntu Desktop/Server, which defaults to netplan), so this file works directly:

```
auto eth0.30
iface eth0.30 inet static
    address 10.10.30.10
    netmask 255.255.255.0
    gateway 10.10.30.1
    vlan-raw-device eth0
    up ip route add 10.10.50.0/24 via 10.10.30.1 dev eth0.30
```

The final `up ip route add` line adds a static route to the Windows zone (`10.10.50.0/24`), needed because the default gateway only automatically covers Kali's own subnet.

## 5. Recovery Commands (if the VLAN interface is missing after an unexpected reboot)

```bash
ip addr show eth0.30   # check if it exists first
sudo ip link add link eth0 name eth0.30 type vlan id 30
sudo ip addr add 10.10.30.10/24 dev eth0.30
sudo ip link set eth0.30 up
sudo ip route add 10.10.50.0/24 via 10.10.30.1 dev eth0.30
```

## Verified Connectivity (from Kali, 10.10.30.10)

| Target | Result |
|---|---|
| 10.10.20.1 (VICTIMS GW) | ✅ Reachable |
| 10.10.30.1 (own gateway) | ❌ Not pingable from self — normal, not a bug |
| 10.10.40.1 (LEGACY GW) | ✅ Reachable |
| 10.10.50.1 (WIN GW) | ✅ Reachable |
| 10.10.20.10 (Ubuntu) | ✅ Reachable |
| 10.10.40.10 (Metasploitable2) | ✅ Reachable |
| 10.10.50.100 (Windows), ping + RDP | ✅ Reachable |
