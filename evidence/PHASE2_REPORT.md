# Phase 2 Report — Team Kuch_Nahi
**Computer Networks Project | B.Tech CSE | 2024 Batch**

| Person | Mac | IP | Role |
|--------|-----|----|------|
| Hardik Hathwal | Mac 1 | `10.7.6.152` | Primary DNS + Client |
| Abuzar Haider | Mac 2 | `10.7.31.75` | Primary Nginx HTTPS Edge |
| Kabir Sharma | Mac 3 | `10.7.11.100` | Backend A (3001) + Standby Edge |
| Ayush Tiwari | Mac 4 | `10.7.15.153` | Backend B (3002) + Backup DNS + Client |

---

## Architecture Diagram (Phase 2)

```
                     iPhone Hotspot LAN (10.7.0.0/19)
┌───────────────────────────────────────────────────────────┐
│                                                           │
│  Mac 1 — Hardik          Mac 2 — Abuzar                  │
│  10.7.6.152              10.7.31.75                       │
│  [PRIMARY DNS :53]  ───► [PRIMARY NGINX :8443]            │
│        │                       │                          │
│        │  DNS answer:          │  load-balances           │
│        │  10.7.31.75           ├──────────────────┐       │
│        │                       ▼                  ▼       │
│  Mac 4 — Ayush          Mac 3 — Kabir    Mac 4 — Ayush   │
│  10.7.15.153            10.7.11.100      10.7.15.153      │
│  [BACKUP DNS :53]       [Backend A:3001] [Backend B:3002] │
│  [STANDBY CLIENT]       [STANDBY EDGE:8443]               │
│                                                           │
└───────────────────────────────────────────────────────────┘

Request flow (normal):
Client → dig app.Kuch_Nahi.test → Mac 1 (DNS) → returns 10.7.31.75
Client → HTTPS :8443 → Mac 2 (Nginx) → round-robin → Mac 3 or Mac 4 backend

Failover flow (DNS cutover):
Hardik edits dnsmasq record → 10.7.31.75 becomes 10.7.11.100
After TTL (30 s) → clients resolve to Mac 3 → Kabir's standby nginx serves traffic
```

---

## Extension A — Backup DNS

### What We Did
- All 4 Macs set DNS to both servers: `10.7.6.152 10.7.15.153`
- Ayush ran her own dnsmasq instance on `10.7.15.153` with identical records

### Demo Steps
1. Ayush ran `dig app.Kuch_Nahi.test` → `SERVER: 10.7.6.152` (primary)
2. Hardik ran `sudo brew services stop dnsmasq` (killed primary DNS)
3. Ayush ran `dig app.Kuch_Nahi.test` → `SERVER: 10.7.15.153` (automatic fallback)
4. Ayush ran `/usr/bin/curl` → website still worked through Nginx
5. Hardik restarted dnsmasq

### Result
✅ macOS automatically fell back to the backup DNS server within seconds.
No manual intervention. The website remained fully available.

### Key Insight
> A DNS failure stops name resolution — `dig` fails and apps cannot connect.
> A backend failure leaves DNS working but Nginx returns 502.
> These are different failure modes at different layers.

### Evidence
| File | Description |
|------|-------------|
| `evidence/screenshots/phase2/A-backup-dns-primary-before.jpeg` | Ayush's dig showing `SERVER: 10.7.6.152` before Hardik stops dnsmasq |

---

## Extension B — TTL and DNS Cutover

### What We Did
- Hardik changed the dnsmasq A-record for `app.Kuch_Nahi.test` from `10.7.31.75` to `10.7.11.100`
- Demonstrated that cached DNS answers persist until TTL (30 s) expires
- Showed that a cache flush makes the switch instant
- Restored the record and demonstrated the flush-restore

### Demo Steps
1. Ayush started a live ping loop against `app.Kuch_Nahi.test` (shows resolved IP)
2. Hardik changed the DNS record to `10.7.11.100` and restarted dnsmasq
3. Hardik immediately ran curl → got `X-Edge: standby-mac3` (no cache on his Mac)
4. Ayush's loop continued showing `10.7.31.75` for ~30 s, then flipped to `10.7.11.100`
5. Hardik restored the record to `10.7.31.75` and restarted dnsmasq
6. Ayush flushed her DNS cache → loop flipped back to `10.7.31.75` **instantly**

### Result
✅ TTL caching demonstrated live — old IP persisted for ~30 s, flush was instant.
✅ Two clients resolved to different IPs at the same time (Hardik=new, Ayush=old).

### Key Insight
> `dig` always queries the DNS server fresh — it skips the OS cache.
> `ping` resolves through the OS cache — shows the old IP until TTL expires.
> Real companies lower TTL before a migration so the old cache expires faster.

### Evidence
| File | Description |
|------|-------------|
| `evidence/screenshots/phase2/B-dns-cutover-standby-mac3.jpeg` | Hardik's curl returning `X-Edge: standby-mac3` immediately after DNS change |
| `evidence/screenshots/phase2/B-ttl-expiry-old-to-new.jpeg` | Ayush's ping loop: `10.7.31.75` entries then flip to `10.7.11.100` at 01:15:06 |
| `evidence/screenshots/phase2/B-flush-new-to-old.jpeg` | Ayush's ping loop: `10.7.11.100` then immediate flip to `10.7.31.75` after cache flush |

---

## Extension D — Backend Failover

### What We Did
- Ayush ran a 6-request loop through Nginx HTTPS edge
- Kabir stopped Backend A (port 3001)
- Loop continued hitting only Backend B — zero errors
- Kabir restarted Backend A — both backends alternated again after ~10 s

### Demo Steps
1. Ayush ran loop → `X-Backend: B, A, B, A, B, A` (round-robin)
2. Kabir pressed `Ctrl+C` on `server.py` (Backend A down)
3. Ayush ran loop → `X-Backend: B, B, B, B, B, B` (automatic failover, no errors)
4. Kabir restarted Backend A
5. After ~10 s, Ayush ran loop → A and B alternating again

### Result
✅ Nginx detected the backend failure automatically via `max_fails=1 fail_timeout=10s`.
✅ No 5xx errors seen by the client during the outage.

### Key Insight
> The single point of failure is the Nginx edge itself (Mac 2 / Abuzar).
> Backend failover is handled inside Nginx — transparent to the client.
> Edge failover requires a DNS-layer cutover (Extension B).

### Evidence
| File | Description |
|------|-------------|
| `evidence/screenshots/phase2/D-load-balancing-normal.jpeg` | Ayush's 6-request loop: `X-Backend: B, A, B, A, B, A` alternating correctly |

---

## Extension C — Firewall Isolation

### What We Did
- Kabir applied `pf` rules on Mac 3 (port 3001): only allow `10.7.31.75` (Abuzar's Nginx)
- Ayush applied `pf` rules on Mac 4 (port 3002): same whitelist
- Demonstrated that direct LAN access is blocked while edge access still works

### Demo Steps
1. **Before firewall** — Hardik curled both backends directly → both returned `200 OK`
2. Kabir and Ayush enabled `pf` rules
3. **After firewall** — Hardik curled both backends → both timed out after 5 s
4. Abuzar curled both backends from Mac 2 → both returned `200 OK` (edge is whitelisted)
5. Hardik curled via HTTPS edge → `200 OK` (normal users unaffected)
6. Kabir and Ayush restored `pf` to original state

### Result
✅ Direct LAN access to backend ports blocked for all non-whitelisted hosts.
✅ Nginx edge (10.7.31.75) retained full access.
✅ HTTPS traffic through the edge continued to work normally for end users.

### Key Insight
> This is a zero-trust backend isolation pattern. Backends are only reachable
> via the authorised reverse proxy. Even if an attacker is on the same LAN,
> they cannot directly hit port 3001 or 3002.

### Evidence
| File | Description |
|------|-------------|
| `evidence/screenshots/phase2/C-firewall-before-open.jpeg` | Hardik's curl BEFORE pf: both backends return JSON `200 OK` |
| `evidence/screenshots/phase2/C-firewall-after-blocked.jpeg` | Hardik's curl AFTER pf: both time out (`curl: (28) Connection timed out`) |
| `evidence/screenshots/phase2/C-firewall-edge-access.jpeg` | Abuzar's curl: both backends still accessible from `10.7.31.75` |
| `evidence/screenshots/phase2/C-firewall-https-works.jpeg` | Hardik's HTTPS curl via Nginx: `200 OK` (end users unaffected) |
| `evidence/screenshots/phase2/C-firewall-kabir-restore.jpeg` | Kabir restoring pf with `pfctl -f ~/pf.conf.backup` |
| `evidence/screenshots/phase2/C-firewall-ayush-restore.jpeg` | Ayush restoring pf with `pfctl -f backup + pfctl -d` |

---

## What Changed from Phase 1

| Aspect | Phase 1 | Phase 2 Addition |
|--------|---------|-----------------|
| DNS | Single dnsmasq on Mac 1 | Backup dnsmasq on Mac 4 — failover tested live |
| Edge | Single nginx on Mac 2 | Standby nginx on Mac 3, DNS-cutover tested with TTL |
| Backends | Both backends always up | Backend failover with nginx health check (`max_fails=1`) |
| Firewall | No restrictions | pf rules: backends reachable only from nginx edge |
| Security | HTTPS only at edge | Zero-trust backend isolation — LAN clients cannot hit backends directly |
| Observability | X-Backend header | X-Edge header added to standby, tokens logged per pf enable |

---

## Extension F — Troubleshooting Methodology

> Extension F is a faculty-injected fault. The team was not assigned a specific fault but
> we documented our layer-by-layer diagnosis playbook, which we used throughout Phase 2.

### Diagnosis Playbook (Layer by Layer)

```
Symptom: "The website doesn't load" / "curl fails"

Layer 1 — Physical / LAN
  → ping 10.7.31.75 (edge)
  If ping fails: check Wi-Fi, same network? → ARP table (arp -a)

Layer 2 — DNS
  → dig app.Kuch_Nahi.test @10.7.6.152
  If SERVFAIL: dnsmasq not running on Mac 1 → try backup (10.7.15.153)
  If NXDOMAIN: wrong domain / misconfigured dnsmasq record

Layer 3 — TCP connectivity
  → nc -zv 10.7.31.75 8443
  If refused: nginx not running on Mac 2 → sudo nginx
  If timeout: pf firewall blocking? → sudo pfctl -d (test)

Layer 4 — TLS
  → curl -v --cacert ~/Downloads/ca.crt https://app.Kuch_Nahi.test:8443/
  If certificate error: wrong CA / SAN mismatch / cert expired
  If handshake timeout: nginx ssl config wrong

Layer 5 — Application (HTTP)
  → curl response body / HTTP status code
  502 Bad Gateway: both backends down? → check server.py on Mac 3 + Mac 4
  503 Service Unavailable: nginx upstream pool empty
  200 but wrong data: check X-Backend header to identify which backend answered
```

### Real Issues We Diagnosed in Phase 2

| Fault | Symptom | Root Cause | Fix |
|-------|---------|------------|-----|
| curl shows blank X-Edge | No header in response | Kabir's nginx had old config (no X-Edge) | Kabir updated and reloaded nginx |
| TLS error on standby IP | Certificate error | cert SAN has DNS name only, not IP SAN | Used `--resolve` or proper DNS cutover |
| Ayush pf already disabled | `pf disabled` in pfctl output | pf was not running before the lab | Expected — restored to same state |
| Conda curl ignoring CA | No cert errors (bad!) | Conda's curl uses its own CA bundle | Switched to `/usr/bin/curl --cacert` |

---

## Learning Summary

### Extension A — Backup DNS
DNS is often treated as "just works", but it is a critical single point of failure.
Running a secondary dnsmasq with identical records on a different machine costs nothing
and eliminates the DNS layer as a single point of failure. macOS's resolver automatically
tries the second server when the first doesn't respond — no client config change needed.
Real-world equivalent: Route 53 with health checks and failover routing policies.

### Extension B — TTL and DNS Cutover
TTL is not just a metadata field — it is a live operational parameter.
Lowering the TTL 24 hours before a migration (e.g. from 86400 to 30) means that
the old cached answer expires quickly during the cutover. We observed that two clients
on the same LAN resolved the same hostname to different IPs simultaneously — one
had a fresh cache, the other was holding a 30-second-old answer. This is a real
challenge in blue-green deployments and cdn origin migrations.

### Extension C — Firewall / Service Isolation
A backend that listens on `0.0.0.0` and has no firewall is reachable by any host
on the same LAN — including an attacker who gets access to the network. The pf
whitelist pattern (allow only the reverse proxy's IP, block everything else) implements
the zero-trust principle: every connection must be authorised, not just authenticated.
Cloud equivalent: Security Groups on EC2 that only allow inbound from the ALB's SG.

### Extension D — Backend High-Availability
Nginx's upstream health check (`max_fails`, `fail_timeout`) is a simple but effective
way to remove dead backends from the rotation without any manual intervention.
The key observation: the client never received a 5xx error even when Backend A was
killed mid-test. Nginx detected the failure on the first attempt, marked the upstream
as unhealthy, and all subsequent requests went to Backend B. Recovery was equally
automatic — after `fail_timeout` elapsed, Nginx probed Backend A and re-added it.

### Extension E — Edge Migration (DNS Cutover)
Edge migration via DNS cutover is cleaner than changing client configurations.
By lowering the TTL, changing the DNS record, and waiting TTL seconds, we migrated
all clients from the primary nginx (Mac 2) to the standby nginx (Mac 3) without
touching a single client. The `X-Edge: standby-mac3` header confirmed the switch.
Real-world equivalent: Route 53 weighted routing during canary deployments.

### Extension F — Troubleshooting
Every networking problem must be diagnosed layer by layer, starting at Layer 1
(physical/LAN) and working up to Layer 7 (application). Skipping layers wastes time.
The most common mistake is assuming the problem is at the application layer when it
is actually a DNS or TLS issue. Using `ping`, `dig`, `nc`, `curl -v`, and Wireshark
at each layer gives unambiguous evidence of where the fault lies.

---

## Viva Q&A

**Q1: Why did `dig` show the new IP while `ping` showed the old one?**
> `dig` sends a fresh DNS query to the server every time — it bypasses the OS resolver cache.
> `ping` resolves the hostname using the OS's DNS cache, which still holds the old answer
> until the TTL (30 seconds) expires. That is why we used `ping` in the loop — to show
> the cache aging out in real time.

**Q2: What is the difference between a DNS failure and a backend failure?**
> DNS failure: the name does not resolve at all — `dig` returns SERVFAIL or times out,
> and the client cannot even open a TCP connection.
> Backend failure: DNS resolves fine, TCP connects to Nginx on 8443, but Nginx cannot
> reach the backend and returns `502 Bad Gateway`. The network layer is healthy;
> the application layer is broken.

**Q3: What is the single point of failure, and how would you remove it?**
> The Nginx HTTPS edge on Mac 2 (Abuzar, 10.7.31.75). If that machine goes down,
> DNS still resolves but all HTTPS requests fail.
> Fix: provision a standby edge (Kabir's Mac 3 at 10.7.11.100 with identical nginx config),
> and use a DNS cutover to switch `app.Kuch_Nahi.test` from 10.7.31.75 to 10.7.11.100.
> With a low TTL (30 s) the failover completes within half a minute.

**Q4: Where does the TCP handshake end and TLS begin?**
> TCP ends after the 3-way handshake: SYN → SYN-ACK → ACK. At that point the
> connection is established at Layer 4.
> TLS begins immediately after with the `ClientHello` message — still on the same TCP
> connection but now at Layer 5/6. In Wireshark you see `tcp.flags.syn==1` for the
> handshake, then `tls.handshake` for ClientHello, ServerHello and Certificate.
> The application data (`GET /api/status`) is only sent after `Finished` messages exchange.

