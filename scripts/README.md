# Scripts

Automation for reproducing this lab's network setup, instead of relying only on the prose steps in `docs/`. Each script mirrors a configuration that's already documented and tested — nothing here does anything the docs don't already describe manually.

| Script | Runs on | Purpose |
|---|---|---|
| `provision-pfsense-networks.sh` | Host (Windows, via Git Bash) | Creates the VirtualBox Internal Networks and attaches the 5th NIC to pfSense-Gateway via `VBoxManage` |
| `setup-kali-vlan.sh` | Kali-Attacker (guest) | Configures persistent VLAN 30 tagging via `/etc/network/interfaces` |
| `setup-ubuntu-vlan.sh` | Ubuntu-Victim (guest) | Configures persistent VLAN 20 tagging via `/etc/rc.local` |
| `setup-metasploitable2-network.sh` | Metasploitable2 (guest) | Configures persistent static IP via `/etc/network/interfaces` |

## Usage

**Host script** — run once, before pfSense's network adapters are configured in the GUI:

```bash
chmod +x provision-pfsense-networks.sh
./provision-pfsense-networks.sh
```

**Guest scripts** — copy the relevant script to the VM (or paste its contents) and run as root:

```bash
sudo bash setup-kali-vlan.sh          # on Kali-Attacker
sudo bash setup-ubuntu-vlan.sh        # on Ubuntu-Victim
sudo bash setup-metasploitable2-network.sh   # on Metasploitable2
```

## What these scripts don't do

They don't touch pfSense's own configuration (interface assignment, firewall rules, WireGuard) — that's all done through the pfSense GUI and isn't scriptable from outside without the pfSense API or a config.xml import, which isn't set up here. See `docs/01-hypervisor-setup.md` for those steps, and `configs/` for the firewall rule reference.

Each script is idempotent where practical (checks before re-adding a VLAN interface that already exists) but hasn't been tested against every possible starting state — read through a script before running it on a VM you care about.
