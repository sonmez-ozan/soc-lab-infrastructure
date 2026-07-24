# ADR 003: Use ZFS instead of UFS for pfSense's filesystem

## Status
Accepted

## Context
pfSense's installer offers ZFS (current recommended default) or UFS
(legacy, lighter-weight) as the filesystem. ZFS offers snapshots, data
integrity checksumming, and compression, but traditionally wants more
RAM/resources to perform well — largely not a concern relevant to a small
1 vCPU / 1GB RAM router VM.

## Decision
Use ZFS, matching the modern recommended default, since host hardware
(32GB RAM) has ample headroom to absorb any overhead.

## Consequences
- Slightly higher resource use on the pfSense VM than UFS would need,
  but negligible given available host resources
- Stays consistent with current best practice and default tooling
  behavior, rather than optimizing for a marginal resource saving
- Snapshot/rollback capability available if ever needed for this VM