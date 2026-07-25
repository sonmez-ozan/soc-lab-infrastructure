# ADR-006: Drop the Tagged Management VLAN, Use Native LAN Instead

**Status:** Accepted

## Context

The original design tagged three VLANs on the trunk interface `em1`: VLAN 10 (Management), VLAN 20 (Victims), VLAN 30 (Attacker). When attempting to create the VLAN 10 interface in pfSense, it was rejected:

> IPv4 address 10.10.10.1/24 is being used by or overlaps with: LAN

This happened because the physical LAN interface already held `10.10.10.1/24` from initial pfSense setup, before VLANs were introduced.

## Decision

Delete the VLAN 10 interface assignment entirely. Keep the existing native/untagged LAN interface as the Management zone directly, and layer the Victims (VLAN 20) and Attacker (VLAN 30) tags on top of the same trunk.

## Consequences

- One less redundant interface to maintain.
- This matches a common, valid real-world pattern: the native/untagged VLAN on a trunk serves as the trusted management network, with additional tagged VLANs layered on top for other zones.
- Management traffic is now technically untagged on the wire, which is fine here since Management doesn't need isolation *from the trunk itself* the way Victims/Attacker do from each other.
