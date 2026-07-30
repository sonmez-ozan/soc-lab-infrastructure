# Configs

## `firewall-rules-summary.md`

A structured, standalone reference of every firewall alias and inter-zone rule configured in pfSense — the same information as `docs/02-network-design.md`'s policy table, kept here separately since it's a config artifact, not narrative documentation.

## Exporting your own pfSense config.xml (optional, do this yourself)

I can't reach your live pfSense instance to pull this automatically — pfSense's full configuration (including things not worth hand-transcribing, like certificates and package state) lives in a single `config.xml` that only pfSense itself can export. To add a real one to this folder:

1. In the pfSense GUI: **Diagnostics → Backup & Restore**
2. Under "Backup", leave the default options (or check "Do not backup RRD data" to keep the file smaller) and click **Download configuration as XML**
3. Save it into this folder as `configs/pfsense-config-backup.xml`

**Before committing it:** open the file and search for anything sensitive — pfSense obscures the admin password hash by default, but double-check for your WireGuard private keys, which are stored in this file in plaintext. If present, either strip them out manually or keep this specific file in a gitignored location instead of committing it, since it's a public repo.
