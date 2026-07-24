# ADR 005: Start with Metasploitable2, add Metasploitable3 later

## Status
Accepted

## Context
Metasploitable2 is a pre-built downloadable VM with older, well-documented
vulnerabilities. Metasploitable3 must be built via Vagrant/Packer scripts,
is significantly more involved to set up, and includes more modern/varied
vulnerabilities (e.g. EternalBlue-class issues).

## Decision
Deploy Metasploitable2 first to validate the detection pipeline
(Suricata/Wazuh visibility into attacks) without the added friction of
Metasploitable3's provisioning process. Add Metasploitable3 (Windows
variant) later once the core lab and detection tooling are stable.

## Consequences
- Faster path to a working attack-simulation environment early on
- Metasploitable3's more modern attack surface becomes a later, more
  advanced portfolio project rather than a blocker to initial progress