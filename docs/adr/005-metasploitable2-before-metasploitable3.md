# ADR-005: Deploy Metasploitable2 Before Metasploitable3

**Status:** Accepted

## Context

Metasploitable2 is a pre-built, downloadable VM image — fast to set up and extensively documented. Metasploitable3 is built via Vagrant/Packer scripts (more involved setup) but includes more modern vulnerability classes (e.g. EternalBlue-class SMB vulnerabilities).

## Decision

Deploy Metasploitable2 first, to keep early effort focused on validating the detection/attack pipeline itself (network segmentation, firewall policy, connectivity) rather than on target-provisioning complexity. Metasploitable3 is planned as a later addition once the core infrastructure (this repo) is stable.

## Consequences

- The current Legacy zone's design (dedicated NIC, no VLAN tagging) was directly informed by Metasploitable2's age — Metasploitable3, being Vagrant/Packer-built on more modern base images, may support VLAN tagging and could potentially join the tagged trunk instead when it's added.
- Faster path to having *a* working vulnerable target for early testing, deferring the more complex build.
