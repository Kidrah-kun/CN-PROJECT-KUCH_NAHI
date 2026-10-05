## Evidence Index — Team Kuch_Nahi
### Computer Networks Project — Phase 1

Place your screenshots and Wireshark captures in the subfolders below.
Rename files exactly as listed so the evaluator can find them within 30 seconds.

---

### Section A — LAN & DNS Evidence

| File | Content | Form Field |
|------|---------|-----------|
| `screenshots/dns/A1-Hardik-Hathwal-IP.jpg` <br> `screenshots/dns/A1-Abuzar-Haider-IP.png` <br> `screenshots/dns/A1-Kabir-Sharma-IP.jpg` <br> `screenshots/dns/A1-Ayush-Tiwari-IP.jpg` | `networksetup -getinfo "Wi-Fi"` from all 4 Macs | A1 |
| `screenshots/dns/A3-dig-private-domain.jpg` | Full `dig app.Kuch_Nahi.test` output (SERVER=10.7.7.36) | A3 |
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
