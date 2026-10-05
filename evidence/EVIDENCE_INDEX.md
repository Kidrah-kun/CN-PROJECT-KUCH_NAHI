## Evidence Index — Team Kuch_Nahi
### Computer Networks Project

Place your screenshots and Wireshark captures in the subfolders below.
Rename files exactly as listed so the evaluator can find them within 30 seconds.

---

### Section A — LAN & DNS Evidence

| File | Content | Form Field |
|------|---------|-----------|
| `screenshots/dns/A1-ip-inventory.png` | `networksetup -getinfo "Wi-Fi"` from all 4 Macs | A1 |
| `screenshots/dns/A2-dnsmasq-config.png` | `grep` output of dnsmasq.conf key lines | A2 |
| `screenshots/dns/A3-dig-private-domain.png` | Full `dig app.Kuch_Nahi.test` output (SERVER=10.7.7.36) | A3 |
| `screenshots/dns/A4-google-dns-nxdomain.png` | Full `dig @8.8.8.8 app.Kuch_Nahi.test` → NXDOMAIN | A4 |
| `screenshots/ping/A5-ping-all-pairs.png` | All 6 pairwise ping results, 0% loss | A5 |

### Section B — HTTPS & nginx Evidence

| File | Content | Form Field |
|------|---------|-----------|
| `screenshots/tls/B1-https-curl-v.png` | Full `curl -v https://app.Kuch_Nahi.test:8443/` (no -k) | B1 |
| `screenshots/load-balancing/B2-load-balancing-6.png` | 6 requests showing alternating X-Backend: A / B | B2 |
| `screenshots/load-balancing/B3-nginx-config.png` | nginx.conf showing upstream + ssl + proxy_pass | B3 |

### Section C — Wireshark Captures

| File | Content | Form Field |
|------|---------|-----------|
| `wireshark/dns-capture.pcapng` | Raw Wireshark DNS capture file | C1 |
| `screenshots/dns/C1-wireshark-dns.png` | DNS query/response screenshot (filter: dns) | C1 |
| `wireshark/tcp-handshake.pcapng` | Raw Wireshark TCP capture | C2 |
| `screenshots/tcp/C2-wireshark-tcp-handshake.png` | SYN→SYN-ACK→ACK (filter: tcp.flags.syn==1) | C2 |
| `wireshark/tls-handshake.pcapng` | Raw Wireshark TLS capture | C3 |
| `screenshots/tls/C3-wireshark-tls.png` | ClientHello→Certificate→AppData (filter: tls) | C3 |

### Section D — Caching & Failure Evidence

| File | Content | Form Field |
|------|---------|-----------|
| `screenshots/caching/D1-cache-headers.png` | `curl -sI` response headers with Cache-Control + ETag | D1 |
| `screenshots/caching/D1-304-not-modified.png` | 304 Not Modified response | D1 |
| `screenshots/failure-demo/D3-before-failure.png` | Load balancing A+B before stopping Backend A | D3 |
| `screenshots/failure-demo/D3-backend-a-stopped.png` | Only X-Backend: B after killing Backend A | D3 |
| `screenshots/failure-demo/D3-after-restore.png` | A+B alternating after restarting Backend A | D3 |

### Phase 2 Evidence

| File | Content |
|------|---------|
| `screenshots/dns/P2-backup-dns-failover.png` | Backup DNS still resolves when Mac 1 is stopped |
| `screenshots/dns/P2-ttl-old-cache.png` | Old cached DNS answer during TTL window |
| `screenshots/dns/P2-ttl-new-answer.png` | New DNS answer after TTL expires |
| `screenshots/failure-demo/P2-firewall-mac2-ok.png` | Mac 2 curl to backend succeeds (allowed) |
| `screenshots/failure-demo/P2-firewall-client-blocked.png` | Client curl to backend times out (blocked) |
