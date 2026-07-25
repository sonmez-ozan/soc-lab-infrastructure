# Testing & Validation

Every meaningful connectivity, isolation, and persistence test run against this lab, with results. Tests build on each other — later tests assume earlier ones passed.

## Test 1 — WireGuard VPN Tunnel Connectivity

**Goal:** confirm remote administrative access works without exposing the pfSense GUI directly to the internet.

**Method:** Checked the WireGuard client's Latest Handshake and Transfer counters (both non-zero and increasing = cryptographically healthy tunnel), then enabled logging on the WireGuard pass rule and confirmed in `Status → System Logs → Firewall` that ICMP from the tunnel IP was logged as **PASSED**.

**Caveat found:** pinging pfSense's *own* tunnel-interface IP (10.10.10.1) directly was unreliable and sometimes timed out, even with a confirmed-healthy tunnel and a firewall log showing the packet passed. This is a known edge case — a firewall replying to a ping addressed to its own interface is a different code path than forwarding traffic to a downstream host. The real, meaningful test is host-to-host traffic through the tunnel (or a reverse ping from pfSense's Diagnostics page to the client), not self-ping.

**Result:** ✅ Tunnel confirmed functional. See [Lessons Learned](05-lessons-learned.md#wireguard-self-ping) for the full troubleshooting story.

## Test 2 — VLAN Tagging (802.1Q): Kali & Ubuntu

**Goal:** confirm each host can tag its own traffic and have pfSense correctly route it.

**Method:** Created a VLAN subinterface in-guest (`ip link add ... type vlan id <n>`), assigned it an IP, brought it up, added a route.

**First result (both hosts):** `ping` to the zone gateway failed 100% even with the interface showing `UP` and correctly addressed.

**Root cause (diagnosed via pfSense firewall log, not assumed):** traffic was arriving correctly tagged, but hitting the interface's **default-deny rule** — pfSense had no explicit Pass rule yet for that zone.

**Fix:** added a Pass rule scoped to the zone's subnet. Re-tested — **0% packet loss** on both.

## Test 3 — Cross-Zone Routing: Attacker → Victim

**Goal:** prove the segmented design actually works host-to-host, not just host-to-gateway.

**Method:** `ping` from Kali (10.10.30.10) to Ubuntu-Victim's tagged address.

**Result:** ✅ 0% packet loss, replies at **TTL=63** (one less than the standard 64) — concrete proof the packet was actually routed through pfSense (one hop), not just exchanged on a shared local segment.

## Test 4 — Firewall Policy Enforcement (Isolation)

**Goal:** prove Victims *cannot* reach Attacker, matching the documented policy.

**Method:** `ping` from Kali → Ubuntu (Attacker → Victims), then `ping` from Ubuntu → Kali (Victims → Attacker).

**Result:**
- Attacker → Victims: ✅ succeeded (allowed by explicit rule)
- Victims → Attacker: ✅ **failed**, 100% loss (correctly denied by default — no explicit deny rule needed)

This asymmetry is the actual evidence the isolation policy is enforced, not just documented.

## Test 5 — Legacy Zone (Metasploitable2)

**Goal:** confirm the dedicated-NIC fallback zone works the same as a tagged VLAN, for a host that can't do VLAN tagging.

**Result:**
- Kali → Metasploitable2: ✅ succeeded, TTL=63 (routed through pfSense)
- Ubuntu → Metasploitable2: ✅ failed, 100% loss (no rule permits Victims → Legacy — correctly denied)

## Test 6 — Windows Zone

**Goal:** same as Test 5, for Windows 11's dedicated-NIC zone.

**Result:**
- Kali → Windows (ping): ✅ 4/4 replies, ~1–4ms RTT
- Kali → Windows, `nmap -p 3389`: ✅ port OPEN
- Kali → Windows, `xfreerdp`: ✅ full desktop session established
- pfSense Diagnostics → Ping → Windows: ✅ confirmed from the firewall itself

## Test 7 — Ubuntu VLAN Persistence Fix (this session)

**Problem going in:** netplan's native `vlans:` key repeatedly failed with "unknown key" errors across several attempts (different key names tried, different file structures). Root cause was never conclusively pinned to a single netplan bug — most likely a combination of manual-edit typos (a missed `s` in `addresses`, a save that silently didn't take) compounding across attempts.

**Approach taken:** abandoned further netplan debugging and used `/etc/rc.local` to bring up the VLAN interface manually and reliably at boot instead.

**Bug found and fixed:** the first rc.local draft had a typo — `enp0s.20` instead of `enp0s3.20` — on the line assigning the IP address. The VLAN interface itself was created correctly (that line had the right name), but the address-assignment line silently failed against a nonexistent device name. Confirmed via `journalctl`/boot log: `rc.local[...]: Cannot find device "enp0s.20"`.

**Second bug found:** even after fixing the typo and confirming the interface was `UP` with the correct address, `ping` to Kali still failed. `tcpdump -i enp0s3 -e -n vlan 20` on Ubuntu confirmed tagged ICMP requests **were** arriving correctly — ruling out the trunk, VLAN tagging, and VirtualBox networking entirely. The actual cause: **rc.local never added a default route**, so Ubuntu could receive the ping but had no path to send a reply back out to Kali's subnet.

**Fix:** added `ip route add default via 10.10.20.1 dev enp0s3.20` to rc.local, later pinned with an explicit `metric 50` to remove ambiguity against a coexisting DHCP-assigned default route on the untagged parent interface (`enp0s3` picks up a Management-zone DHCP address from the trunk's native VLAN).

**Result:** ✅ Kali → Ubuntu: 4/4 replies, 0% loss. Confirmed persistent across a full reboot.

## Test 8 — Metasploitable2 Persistence Fix (this session)

**Problem:** IP configuration (`ifconfig`/`route add`) had to be re-applied manually after every reboot.

**Fix:** wrote a proper `/etc/network/interfaces` (msf2 uses the older `ifupdown` system, not netplan) with a static `eth0` config, then `sudo /etc/init.d/networking restart`.

**Result:** ✅ Kali → Metasploitable2: 4/4 replies, 0% loss immediately, and confirmed persistent — `eth0` and the default route came up automatically after a full `sudo reboot` with zero manual steps.

## Test 9 — Full Cold-Boot Connectivity Sweep (this session)

**Goal:** after fixing Tests 7 and 8, confirm the entire lab comes up correctly from a cold boot with no manual intervention on any VM.

**Method:** rebooted all four VMs, then from Kali:

```bash
ping -c 4 10.10.20.1     # pfSense VICTIMS gateway
ping -c 4 10.10.40.1     # pfSense LEGACY gateway
ping -c 4 10.10.50.1     # pfSense WIN gateway
ping -c 4 10.10.20.10    # Ubuntu-Victim
ping -c 4 10.10.40.10    # Metasploitable2
ping -c 4 10.10.50.100   # Windows 11
xfreerdp /v:10.10.50.100 /u:<user> /p:<password> /cert:ignore
```

**Result:** ✅ All six pings — 0% packet loss. RDP session established successfully. Every VM's networking is now fully persistent with no manual steps required after a reboot.

**Status: this closes out the "Fix Ubuntu VLAN persistence," "Fix Metasploitable2 persistence," and "Full reboot test" items from the original outstanding-tasks list.**
