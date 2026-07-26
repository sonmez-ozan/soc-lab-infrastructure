# Lessons Learned

Troubleshooting notes from this build, written close to when each issue happened rather than reconstructed afterward.

## The Ubuntu VLAN Saga

The single most time-consuming problem in this entire project. A timeline of what was tried and what actually mattered:

1. **First attempt:** netplan's `vlans:` section, various key names (`enp0s3.20`, `vlan20`), repeatedly rejected with "unknown key" errors. Multiple netplan file structures tried, including moving the VLAN block between files, fixing a genuine `address` → `addresses` typo along the way, checking `netplan info` for the renderer type, and trying a parallel `systemd-networkd` `.netdev`/`.network` approach (blocked by a `networkctl reload` polkit authorization issue).
2. **Decision point:** rather than continuing to debug netplan's schema indefinitely, switched to `/etc/rc.local` — a much older, blunter mechanism, but one that doesn't depend on netplan's renderer or schema at all.
3. **Bug #1 — a one-character typo:** the rc.local script's `ip addr add` line referenced `enp0s.20` instead of `enp0s3.20` (missing the `3`). The `ip link add` line above it had the correct name, so the interface *was* created — it just never got an IP, and the boot log said so plainly (`Cannot find device "enp0s.20"`), once anyone looked at it. **Lesson:** when a multi-line script references the same identifier repeatedly, verify every line matches — not just the first one you wrote correctly.
4. **Bug #2 — no default route:** after fixing the typo, the interface was confirmed `UP` with the correct IP — and ping *still* failed. It would have been easy to assume the VLAN tagging itself was broken again. Instead, `tcpdump -i enp0s3 -e -n vlan 20` was used to check what was actually happening on the wire, and it showed tagged ICMP requests arriving correctly. That single piece of evidence ruled out the trunk, the tagging, and VirtualBox networking entirely, and pointed straight at Ubuntu's own routing table — which had no default route at all, only the auto-created connected route for its own subnet. **Lesson:** "the interface looks fine but traffic still fails" almost always means look at the routing table next, not the interface config again.
5. **Final polish:** the parent untagged interface (`enp0s3`) was independently picking up a DHCP default route from the Management zone's native VLAN, coexisting with the new VLAN-20 default route. Both worked by coincidence (metric 0 beat metric 100), but this was pinned explicitly with `metric 50` to remove the ambiguity rather than rely on default tie-breaking behavior.

**Takeaway:** three completely different bugs (schema rejection, a typo, a missing route) stacked on top of each other and looked, from the outside, like "one persistent VLAN problem." Isolating each one required a different diagnostic tool each time — reading the actual boot log, then a packet capture, then the routing table — rather than re-trying the same fix repeatedly.

## WireGuard Self-Ping Mystery

The WireGuard tunnel showed "0 B received" and "Latest handshake: never" for an extended troubleshooting session, despite configuration that all appeared correct. Ruled out, in order:

- **OPT1 (host-only) UDP firewall rule** — confirmed present; basic host-only reachability outside the tunnel was fine.
- **`tun_wg0` never assigned as a real pfSense interface** — this was a real missing step (found sitting unassigned under Interfaces → Assignments → Available network ports), fixed by assigning and enabling it — but didn't fix the handshake by itself.
- **Pre-shared key mismatch** — pfSense's peer config had a PSK value while the Windows client had none (classic one-sided-PSK gotcha). Cleared to match — still didn't fix it alone.
- **Clock/timezone skew** — verified pfSense (UTC) and Windows (EDT) were the same instant. A dead end here, but clock skew is a common cause of WireGuard handshake failures and worth checking early.
- **Windows Defender Firewall** — confirmed fully OFF during testing; handshake still failed.
- **"Block private networks" on OPT1** — already unchecked, not the cause.

**Resolution:** after fully closing and reopening the laptop overnight, the handshake completed successfully on its own the next day. The most likely explanation is a stale VirtualBox Host-Only adapter or OS networking state that a full restart cleared — not any single pfSense or WireGuard misconfiguration. No single "aha" fix was found; the eliminative process (ruling out six plausible causes one at a time, with firewall logging turned on to get authoritative pass/block evidence rather than guessing from `ping` output) is what made it possible to trust that the eventual resolution was real rather than coincidental.

**Related, still-open observation:** pinging pfSense's own tunnel interface IP through the tunnel continued to time out even after the handshake was confirmed healthy and firewall logs showed the ICMP request PASSING. This is a known self-ping edge case (see [Glossary](00-glossary-and-tools.md)), not a real problem — a host-to-host ping through the tunnel is the test that matters, not a firewall pinging itself.

## The pfSense Adapter Slot Mis-Assignment

While adding the new adapter for the Legacy zone, the new `soclab-legacy` network was accidentally attached to the same VirtualBox adapter slot that was already carrying `OPT1` (Host-only management access). This wasn't caught until after a pfSense reboot, when the web GUI became completely unreachable.

**Diagnosis, not guesswork:**
- Pinged `192.168.56.10` from Windows — 100% loss (after first catching and correcting an unrelated typo, `195.x` instead of `192.x`, in an earlier ping attempt).
- Checked `ipconfig` on the host — the Host-only adapter itself was healthy and correctly showed `192.168.56.1`, ruling out a host-side fault.
- Cross-referenced pfSense's console interface list (`OPT1 → em2 → 192.168.56.10/24`) against VirtualBox's adapter numbering (Adapter 1 = em0, Adapter 2 = em1, Adapter 3 = em2...) — this revealed Adapter 3 needed to remain the Host-only adapter, but had been reassigned to `soclab-legacy` instead.
- Also had to separately rule out that pfSense had simply been halted via the console's "Halt system" option at one point during the same troubleshooting window, which independently explained an earlier, unrelated round of connectivity loss.

**Fix:** Adapter 3 restored to Host-only; the new Legacy network moved to the next free adapter slot (Adapter 4) instead.

**Lesson:** VirtualBox numbers adapters strictly by slot, and pfSense's `emN` device names map directly to those slots in the order they were originally attached. Any time a new adapter is added to a VM that already has working interfaces assigned, check the slot mapping explicitly before assuming a new adapter landed in an empty slot.

## Windows Firewall Scope: "Local Subnet" vs "Any IP"

RDP and ping to the Windows 11 VM initially failed from Kali despite the relevant Windows Firewall rules being enabled. The key diagnostic clue: **pfSense itself could ping Windows fine**, while Kali couldn't. Since pfSense (10.10.50.1) is on the *same* subnet as Windows (10.10.50.0/24) but Kali (10.10.30.0/24) is not, this asymmetry pointed directly at rule scope rather than the rule's existence. The default scope for these rules is "Local subnet," which silently blocks any source outside that subnet even with the rule enabled. Changing the scope to "Any IP address" fixed it immediately.

**Lesson:** when a firewall rule "should" work but doesn't, and a same-subnet test succeeds while a cross-subnet test fails, check the rule's *scope*, not just whether it's enabled.

## Git/GitHub Workflow Gotchas

- `git push` rejected with `! [rejected] main -> main (fetch first)` when the repo was created on GitHub with an auto-generated README the local clone never had — fixed with `git pull` (merge commit), then `git push`.
- Vim, the default Git commit-message editor, is a common stumbling block: if a merge-message editor session looks "stuck," press **Escape** first, then `:wq` + Enter to save, or `:q!` + Enter to abort without saving. Switching the default editor to Nano avoids this entirely: `git config --global core.editor "nano"`.
- A commit attempt failed with `fatal: not a git repository` because the commands were run from the Windows home directory (`~`) rather than from inside the actual cloned repo folder — always confirm the working directory with `pwd`/`ls` before assuming a git command's context.
