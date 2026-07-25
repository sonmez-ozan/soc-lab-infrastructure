# ADR-002: pfSense CE Over OPNsense

**Status:** Accepted

## Context

Both pfSense CE and OPNsense are free, open-source firewall/router distributions built on FreeBSD's `pf` packet filter. pfSense's current download flow requires creating a free Netgate account and going through their store checkout (even for the $0 Community Edition); OPNsense requires no account at all for its ISO download.

## Decision

Use pfSense CE despite the account/checkout friction, primarily for its larger install base and more extensive third-party tutorial/documentation availability — valuable for a learning-focused first build.

## Consequences

- One extra account-creation step during setup that OPNsense would have avoided.
- Broader community documentation made troubleshooting (VLANs, WireGuard, interface assignment) easier to research throughout this build.
- The underlying `pf`-based firewall concepts transfer directly to OPNsense if a future project wants to compare the two.
