# Firewall Rules Summary

Standalone reference for every pfSense alias and inter-zone firewall rule in this lab. Source of truth for the *policy*; see `docs/02-network-design.md` for the reasoning behind it, and `docs/02-testing.md` for the tests that verified it actually behaves this way.

## Aliases

| Name | Type | Value |
|---|---|---|
| `Management_Net` | Network(s) | `10.10.10.0/24` |
| `Victims_Net` | Network(s) | `10.10.20.0/24` |
| `Attacker_Net` | Network(s) | `10.10.30.0/24` |

## Rules by Interface

### ATTACKER
| Action | Protocol | Source | Destination | Description |
|---|---|---|---|---|
| Pass | Any | Attacker_Net | Victims_Net | Allow Attacker to reach Victims |
| Pass | Any | Attacker_Net | `10.10.40.0/24` | Allow Attacker to reach Legacy zone |
| Pass | Any | Attacker_Net | `10.10.50.0/24` | Allow Attacker to reach Windows zone |

### VICTIMS
| Action | Protocol | Source | Destination | Description |
|---|---|---|---|---|
| Pass | Any | `10.10.20.0/24` | any | Allow Victims outbound |

*(No rule permits Victims → Attacker. This is intentional — pfSense's default-deny handles it. Verified in `docs/02-testing.md`, Test 4.)*

### LEGACY
| Action | Protocol | Source | Destination | Description |
|---|---|---|---|---|
| Pass | Any | `10.10.40.0/24` | any | Allow Legacy outbound |
| Pass | Any | `10.10.40.0/24` | `10.10.20.0/24` | Allow Legacy to reach Victims |

### WIN
| Action | Protocol | Source | Destination | Description |
|---|---|---|---|---|
| Pass | Any | `10.10.50.0/24` | any | Allow Windows zone outbound |
| Pass | Any | `10.10.50.0/24` | `10.10.20.0/24` | Allow Windows zone to reach Victims |

### HOSTACCESS
| Action | Protocol | Source | Destination | Description |
|---|---|---|---|---|
| Pass | TCP | `192.168.56.1` | `192.168.56.10:443` | Host → pfSense GUI (HTTPS) |
| Pass | ICMP | `192.168.56.1` | `192.168.56.10` | Host → pfSense (ping) |
| Pass | UDP | any | This Firewall, port 51820 | Allow WireGuard handshakes |

## Policy Summary

- **Attacker** can reach every other zone (Victims, Legacy, Windows) — this is deliberate, it's the zone used to simulate attack traffic.
- **Victims, Legacy, and Windows** can each reach outbound and reach Victims specifically (for future monitoring/agent traffic), but cannot initiate connections to Attacker or to each other beyond what's listed above.
- **Everything not explicitly listed above is denied** by pfSense's default-deny policy — no rule needed to enforce this, it's the baseline behavior of every interface.
