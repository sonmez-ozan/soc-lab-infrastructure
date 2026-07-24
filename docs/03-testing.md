# Testing & Validation

This document records connectivity tests performed to validate the network
design described in `02-network-design.md`.

## Test 1: WireGuard VPN Tunnel Connectivity

**Goal:** Confirm remote access into the lab works via WireGuard.

**Result:** Pass.
- Tunnel handshake completes and stays current
- Bidirectional traffic confirmed (bytes sent/received increasing)
- pfSense → client ping (10.10.99.2): 0% packet loss, ~0.9ms RTT

**Note:** Pinging pfSense's own interface IP (10.10.10.1) *from* the client
through the tunnel intermittently fails, while pfSense-initiated pings to
the client succeed. This is suspected to be an asymmetric routing/self-ping
quirk specific to a firewall replying to pings on its own interface address,
not a tunnel or firewall rule problem — forwarded traffic to real hosts
(see Test 3) is unaffected.

## Test 2: VLAN Tagging (802.1q)

**Goal:** Confirm each VM correctly tags outbound traffic for its assigned
VLAN, and pfSense receives and routes it.

**Method:** On each VM, a tagged sub-interface was created:
```bash
sudo ip link add link <iface> name <iface>.<vlan_id> type vlan id <vlan_id>
sudo ip addr add <ip>/24 dev <iface>.<vlan_id>
sudo ip link set <iface>.<vlan_id> up
sudo ip route add default via <gateway>
```

| VM             | Interface     | VLAN | IP             | Ping to gateway | Result |
|----------------|---------------|------|----------------|------------------|--------|
| Kali-Attacker  | eth0.30       | 30   | 10.10.30.100   | 10.10.30.1       | 0% loss |
| Ubuntu-Victim  | enp0s3.20     | 20   | 10.10.20.20    | 10.10.20.1       | 0% loss |

**Troubleshooting note:** Both VLANs initially failed with 100% packet loss
despite correct tagging, confirmed via pfSense firewall logs to be hitting
the "Default deny rule IPv4" — no pass rule existed yet on the corresponding
OPT interface. Adding an explicit pass rule (source: VLAN subnet, any
protocol/destination) resolved this immediately. Lesson: pfSense denies all
traffic by default per interface; tagging alone does not grant connectivity.

## Test 3: Cross-VLAN Host-to-Host Routing (Attacker -> Victim)

**Goal:** Prove the network design works for its actual purpose — an
attacker-zone host reaching a real target on the victim zone, through
pfSense.

**Command (from Kali-Attacker):**
```bash
ping -c 3 10.10.20.20
```

**Result:** Pass — 3/3 packets received, 0% packet loss, RTT ~1.2-1.7ms.

TTL on replies was 63 (vs. 64 within a single segment), confirming the
packet was routed through one hop (pfSense) rather than staying local —
expected behavior when two hosts on different VLANs communicate through
a router.

**Conclusion:** The segmented VLAN design, pfSense inter-VLAN routing, and
firewall pass rules all function correctly together. This is the first
successful end-to-end demonstration of the lab's core purpose.

## Known Limitations / Follow-ups

- Firewall rules on OPT3VICTIMS and OPT4ATTACKER are currently permissive
  (Any protocol, Any destination) to establish baseline connectivity. Per
  the policy in `02-network-design.md`, these need to be tightened:
  Victims -> Attacker should be explicitly denied and verified with a
  failed-ping test as evidence.
- Only host-to-gateway and one Attacker->Victim path have been tested.
  Additional victim hosts (Windows, Metasploitable2) still need to be
  built and validated the same way.