# Installing & Configuring Win11-Victim

**Status: ✅ Working, persistent, RDP confirmed.**

## 1. VM Creation

- Name: `Win11-Victim`. ISO: Windows 11 (English x64).
- Unattended Installation left unchecked — walked through each step manually.
- 4096 MB RAM, 2 CPUs, 64 GB disk (new virtual hard disk).
- VirtualBox auto-configures EFI, TPM 2.0, and Secure Boot from Windows 11 OS-type detection — all three are hard requirements for setup to even start; confirm present under Settings → System before booting.
- Network adapter initially on `soclab-net`, later moved to a dedicated zone (see Section 4).

## 2. Black-Screen Fix (Graphics Controller)

If the VM shows a persistent black screen despite "Running" state and the ISO is confirmed attached: check **Settings → Display → Graphics Controller**. `VBoxVGA` (the older default) is incompatible with modern Windows guest boot graphics and may show an "Invalid settings detected" warning. Change it to **VMSVGA** — the modern, Microsoft/Oracle-recommended controller for Windows 10/11 guests.

If a black screen recurs later during OOBE with all resolution options greyed out (display negotiation not active), a `Machine → Reset` is safe — it resumes at the exact OOBE step reached before, with no progress lost.

If the EFI "Continue" option loops back to itself instead of proceeding: enter **Boot Manager** directly and select the listed "UEFI VBOX CD-ROM" entry.

## 3. Local Account (Skip Microsoft Account)

If the "sign-in options" / "I don't have internet" link isn't visible because the VM has live internet via NAT:

1. While the VM is **running**, go to Devices → Network → Network Settings and uncheck "Enable Network Adapter" (this can't be done from VirtualBox's Settings dialog while running — it must be from the guest-facing Devices menu)
2. With no network, "Sign in" now surfaces a "Let's connect you to a network" fallback screen instead
3. From that screen, press **Shift+F10** to open a Command Prompt, then run:
   ```
   OOBE\BYPASSNRO
   ```
4. The system reboots; on return to the same screen, the local-account/limited-setup path is now available
5. Re-enable the network adapter afterward, same attachment as before

## 4. Dedicated Windows Zone (VLAN Limitation)

Checked whether the emulated NIC exposes a settable VLAN ID:

- Device Manager → Network adapters → Intel(R) PRO/1000 MT Desktop Adapter → Advanced tab: a "Priority & VLAN" property exists but is only an on/off toggle, **not a VLAN ID field**
- PowerShell: `Get-NetAdapterAdvancedProperty -Name "Ethernet"` confirms no separate VLAN ID property exists for this driver

**Conclusion:** this is a driver/emulation limitation, not a missing step. Windows gets the same treatment as Metasploitable2 — its own dedicated, untagged zone. See [ADR-003](../04-adr/003-legacy-and-windows-zones-for-non-taggable-hosts.md).

Change the adapter to Internal Network `soclab-win`.

## 5. Static IP

Settings → Network & Internet → Ethernet → IP assignment → Edit → Manual:

| Field | Value |
|---|---|
| IP address | 10.10.50.100 |
| Subnet mask | 255.255.255.0 |
| Gateway | 10.10.50.1 |
| Preferred DNS | 10.10.50.1 |

## 6. Network Profile Fix (Public → Private)

Windows may assign the connection as "Public," which blocks more by default. Fix:

```powershell
Set-NetConnectionProfile -Name "Network 2" -NetworkCategory Private
```

Made persistent via a startup scheduled task:

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-Command Set-NetConnectionProfile -Name 'Network 2' -NetworkCategory Private"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "SetNetworkPrivate" -Action $action -Trigger $trigger -RunLevel Highest -Force
```

## 7. Firewall Rules (kept ON — realistic lab scenario)

Enable specific inbound rules rather than disabling the firewall entirely:

- File and Printer Sharing (Echo Request - ICMPv4-In) — **both** entries, scope **Any IP address**
- Remote Desktop - User Mode (TCP-In) — scope **Any IP address**, all profiles
- Remote Desktop - User Mode (UDP-In) — enabled

> **Important:** the default scope for these rules is "Local subnet," which silently blocks traffic from a *different* zone's subnet even with the rule enabled. Since Kali (10.10.30.0/24) and Windows (10.10.50.0/24) are different subnets, the scope must explicitly be "Any IP address." (pfSense could ping Windows fine even before this fix, because pfSense itself is on the same subnet — this diagnostic difference is what revealed the scope issue.)

## 8. Enable RDP

- Settings → System → Remote Desktop → toggle On
- Registry: `HKLM:\System\CurrentControlSet\Control\Terminal Server` → `fDenyTSConnections = 0`
- Registry: `HKLM:\SYSTEM\CurrentControlSet\Control\Lsa` → `LimitBlankPasswordUse = 0` (also set a real, non-blank password — blank passwords are blocked for RDP regardless of this key)
- **A full reboot is required** — port 3389 does not start listening from just restarting the Remote Desktop service

## 9. Connect from Kali

```bash
xfreerdp /v:10.10.50.100 /u:<username> /p:<password> /cert:ignore
```

**Do not use `/sec:rdp` or `/sec:nla`** — both cause connection failures on this Windows 11 build; default security negotiation works correctly.

## Verified Connectivity

| Test | Result |
|---|---|
| Kali → Windows, ping | ✅ 4/4, ~1–4ms RTT |
| Kali → Windows, `nmap -p 3389` | ✅ OPEN |
| Kali → Windows, `xfreerdp` | ✅ Full session |
| pfSense Diagnostics → Ping → Windows | ✅ Confirmed |
