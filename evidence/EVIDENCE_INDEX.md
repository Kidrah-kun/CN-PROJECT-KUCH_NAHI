## Evidence Index — Team Kuch_Nahi
### Computer Networks Project — Phase 1 + Phase 2

Place your screenshots and Wireshark captures in the subfolders below.
Rename files exactly as listed so the evaluator can find them within 30 seconds.

---

### Section A — LAN & DNS Evidence

| File | Content | Form Field |
|------|---------|-----------| 
| `screenshots/dns/A1-Hardik-Hathwal-IP.jpg` <br> `screenshots/dns/A1-Abuzar-Haider-IP.png` <br> `screenshots/dns/A1-Kabir-Sharma-IP.jpg` <br> `screenshots/dns/A1-Ayush-Tiwari-IP.jpg` | `networksetup -getinfo "Wi-Fi"` from all 4 Macs | A1 |
| `screenshots/dns/A3-dig-private-domain.jpg` | Full `dig app.Kuch_Nahi.test` output (SERVER=10.7.6.152) | A3 |
| `screenshots/dns/A4-google-dns-nxdomain.jpg` | Full `dig @8.8.8.8 app.Kuch_Nahi.test` → NXDOMAIN | A4 |
| `screenshots/ping/A5-mac-1-ping.jpg` <br> `screenshots/ping/A5-mac-2-ping.jpg` <br> `screenshots/ping/A5-mac-3-ping.jpg` <br> `screenshots/ping/A5-mac-4-ping.jpg` | All 6 pairwise ping results, 0% loss | A5 |

### Section B — HTTPS & nginx Evidence

| File | Content | Form Field |
|------|---------|-----------| 
| `screenshots/tls/B1-https-curl-v-A.jpg` <br> `screenshots/tls/B1-https-curl-v-B.jpg` | Full `curl -v https://app.Kuch_Nahi.test:8443/` (no -k) | B1 |
| `screenshots/load-balancing/B2-load-balancing-6.jpg` | 6 requests showing alternating X-Backend: A / B | B2 |

### Section C — Wireshark Captures

| File | Content | Form Field |
|------|---------|-----------| 
| `screenshots/dns/C1-wireshark-dns.jpg` | DNS query/response screenshot (filter: dns) | C1 |
| `screenshots/tcp/C2-wireshark-tcp-handshake.jpg` | SYN→SYN-ACK→ACK (filter: tcp.flags.syn==1) | C2 |
| `screenshots/tls/C3-wireshark-tls.jpg` | ClientHello→Certificate→AppData (filter: tls) | C3 |

### Section D — Caching & Failure Evidence

| File | Content | Form Field |
|------|---------|-----------| 
| `screenshots/caching/D1-cache-headers.jpg` | `curl -sI` response headers with Cache-Control + ETag | D1 |
| `screenshots/caching/D1-304-not-modified.jpg` | 304 Not Modified response | D1 |
| `screenshots/failure-demo/D3-before-failure.jpg` | Load balancing A+B before stopping Backend A | D3 |
| `screenshots/failure-demo/D3-backend-a-stopped.jpg` | Only X-Backend: B after killing Backend A | D3 |

---

## Phase 2 Evidence

### Extension A — Backup DNS

| File | Content |
|------|---------|
| `screenshots/phase2/A-backup-dns-primary-before.jpeg` | Ayush `dig app.Kuch_Nahi.test` → `SERVER: 10.7.6.152` (primary DNS active) |

> ⚠️ Missing: Screenshot of Ayush's dig **after** Hardik stops dnsmasq (should show `SERVER: 10.7.15.153`). Demonstrate live at viva.

### Extension B — TTL and DNS Cutover

| File | Content |
|------|---------|
| `screenshots/phase2/B-dns-cutover-standby-mac3.jpeg` | Hardik's curl → `X-Edge: standby-mac3` immediately after DNS record change |
| `screenshots/phase2/B-ttl-expiry-old-to-new.jpeg` | Ayush ping loop: `10.7.31.75` entries then flip to `10.7.11.100` after TTL (01:15:06) |
| `screenshots/phase2/B-flush-new-to-old.jpeg` | Ayush ping loop: `10.7.11.100` → instant switch to `10.7.31.75` after cache flush |

### Extension D — Backend Failover

| File | Content |
|------|---------|
| `screenshots/phase2/D-load-balancing-normal.jpeg` | Ayush's 6-request loop: `X-Backend: B, A, B, A, B, A` alternating |

> ⚠️ Missing: Screenshot of loop showing **only B** after Kabir stops Backend A. Demonstrate live at viva.

### Extension C — Firewall Isolation

| File | Content |
|------|---------|
| `screenshots/phase2/C-firewall-before-open.jpeg` | Hardik direct curl BEFORE pf: both backends return JSON `200 OK` |
| `screenshots/phase2/C-firewall-after-blocked.jpeg` | Hardik direct curl AFTER pf: both time out (`curl: (28) Connection timed out after 5006 ms`) |
| `screenshots/phase2/C-firewall-edge-access.jpeg` | Abuzar curl from `10.7.31.75`: both backends return `200 OK` (whitelisted edge) |
| `screenshots/phase2/C-firewall-https-works.jpeg` | Hardik HTTPS curl via Nginx: `{"status":"ok","backend":"B"}` — users unaffected |
| `screenshots/phase2/C-firewall-kabir-restore.jpeg` | Kabir `pfctl -f ~/pf.conf.backup` — rules restored |
| `screenshots/phase2/C-firewall-ayush-restore.jpeg` | Ayush `pfctl -f backup + pfctl -d` — pf disabled (was disabled before) |

---

## Phase 2 Config Files

| File | Purpose |
|------|---------|
| `configs/phase2/backup-dnsmasq.conf` | Ayush's backup dnsmasq config (listen on 10.7.15.153) |
| `configs/phase2/standby-nginx.conf` | Kabir's standby nginx config (X-Edge: standby-mac3) |
| `configs/phase2/cn-extra-port3001.rules` | pf rules for Mac 3: only allow 10.7.31.75 on port 3001 |
| `configs/phase2/cn-extra-port3002.rules` | pf rules for Mac 4: only allow 10.7.31.75 on port 3002 |

---

## Architecture & Setup Documents

| File | Purpose |
|------|---------|
| `evidence/ARCHITECTURE.md` | Full topology, IP/MAC table, OSI layer map, cloud equivalents, HA diagram |
| `configs/SETUP_NOTES.md` | Step-by-step setup: dnsmasq, nginx, TLS, backends, pf firewall, end-to-end test |

---

## Demo Prep — Live Evidence Needed at Viva

The following items are **not in screenshots** and must be demonstrated live:

| Demo Step | What to show | Who |
|-----------|-------------|-----|
| Backup DNS after | `dig` showing `SERVER: 10.7.15.153` after Hardik stops dnsmasq | Ayush |
| Backend failover only B | Loop showing only `X-Backend: B` after `Ctrl+C` on Backend A | Ayush + Kabir |
| Wireshark captures | DNS query, TCP SYN handshake, TLS handshake (live or .pcapng) | Hardik |
| 11-step demo | Full live demo sequence per PDF instructions | All 4 |
