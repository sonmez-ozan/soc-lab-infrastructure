# ADR 002: Use pfSense Community Edition over OPNsense

## Status
Accepted

## Context
Both pfSense CE and OPNsense are free, FreeBSD-based, open-source
firewall/router platforms suitable for a home SOC lab. pfSense requires
creating a free Netgate store account to download the installer; OPNsense
does not require any account.

## Decision
Use pfSense Community Edition 2.8.1.

## Consequences
- Extra friction during download (Netgate account/checkout required)
- pfSense has a larger install base and more available tutorials/community
  documentation, which is valuable while still learning
- Skills transfer closely to OPNsense if switched later, since both share
  the same FreeBSD/pf firewall foundation