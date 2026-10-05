# 🌐 Private Network Service Platform
### Computer Networks Course Project — CN Phase 1

<div align="center">

![Network](https://img.shields.io/badge/Project-Computer%20Networks-blue?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey?style=for-the-badge&logo=apple)
![DNS](https://img.shields.io/badge/DNS-dnsmasq-green?style=for-the-badge)
![Proxy](https://img.shields.io/badge/Proxy-nginx%20%2B%20TLS-red?style=for-the-badge)
![Backend](https://img.shields.io/badge/Backend-Python%20REST-yellow?style=for-the-badge)

**Domain:** `app.Kuch_Nahi.test` &nbsp;|&nbsp; **Institution:** Rishihood University

</div>

---

## 👥 Team Members

| # | Name | Roll | Role | Machine | Private IP |
|---|------|------|------|---------|-----------|
| 1 | **Hardik Hathwal** | 2401010176 | DNS Server + Client | Mac 1 | `10.7.7.36` |
| 2 | **Abuzar Haider** | — | Nginx HTTPS Reverse Proxy / Load Balancer | Mac 2 | `10.7.19.243` |
| 3 | **Kabir Sharma** | 2401010205 | Backend Server A | Mac 3 | `10.7.21.89` |
| 4 | **Ayush Tiwari** | — | Backend Server B + Client | Mac 4 | `10.7.24.95` |

**Network:** iPhone Hotspot LAN &nbsp;·&nbsp; **Subnet:** `10.7.0.0/19` (255.255.224.0) &nbsp;·&nbsp; **Gateway:** `10.7.0.1`

---

## 🏗️ Architecture

```
                        iPhone Hotspot LAN (10.7.0.0/19)
         ┌──────────────────────────────────────────────────────┐
         │                                                      │
         │  Mac 1 — Hardik                Mac 2 — Abuzar        │
         │  Private DNS                   nginx Edge            │
         │  dnsmasq · UDP 53              HTTPS · TCP 8443      │
         │  10.7.7.36                     10.7.19.243           │
         │      │                               │               │
         │      │  app.Kuch_Nahi.test           │               │
         │      │  → 10.7.19.243               │               │
         │      │                        ┌──────┴──────┐        │
         │      │                        │             │        │
         │  Mac 3 — Kabir           Mac 4 — Ayush               │
         │  Backend A               Backend B + Client          │
         │  Python REST             Python REST + curl          │
         │  TCP 3001                TCP 3002                    │
         │  10.7.21.89              10.7.24.95                  │
         └──────────────────────────────────────────────────────┘

Full Request Flow:
──────────────────
  Client (Mac 3 or Mac 4)
       │
       ▼  dig app.Kuch_Nahi.test
  Mac 1 — dnsmasq (UDP 53)  ──returns 10.7.19.243──►
       │
       ▼  HTTPS request to 10.7.19.243:8443
  Mac 2 — nginx (TLS terminated)
       │  Round-robin load balance
       ├───────────────────────────────────┐
       ▼                                   ▼
  Mac 3 — Backend A (:3001)    Mac 4 — Backend B (:3002)
  X-Backend: A                 X-Backend: B
```

### Protocol / OSI Layer Mapping

| Layer | Protocol | Component in This Project |
|-------|----------|--------------------------|
| Application | DNS, HTTP, REST | dnsmasq, nginx, Python API |
| Session/Transport | TLS 1.2/1.3 | nginx SSL termination (Mac 2) |
| Transport | TCP (8443, 3001, 3002) · UDP (53) | Sockets |
| Network | IPv4 (10.7.x.x /19) | iPhone Hotspot LAN |
| Data Link | Wi-Fi (802.11) | en0 on each MacBook |

---

## 📁 Repository Structure

```
Kuch_Nahi/
│
├── README.md                      ← You are here
├── CN_Project_Doc.pdf             ← Original project specification
│
├── backend-a/
│   └── server.py                  ← Backend A — Mac 3, Kabir (port 3001)
│
├── backend-b/
│   └── server.py                  ← Backend B — Mac 4, Ayush (port 3002)
│
├── configs/
│   ├── dnsmasq/
│   │   └── dnsmasq.conf           ← Mac 1 private DNS config
│   ├── nginx/
│   │   └── nginx.conf             ← Mac 2 reverse proxy + load balancer
│   └── tls/
│       └── server.cnf             ← OpenSSL SAN config for TLS cert
│
├── scripts/
│   └── quick-test.sh              ← Full-stack test from any client Mac
│
└── evidence/                      ← Screenshots & Wireshark captures
    ├── wireshark/
    └── screenshots/
        ├── dns/                   ← A2, A3, A4 evidence
        ├── ping/                  ← A5 evidence
        ├── tcp/                   ← C2 Wireshark TCP handshake
        ├── tls/                   ← C3 Wireshark TLS handshake
        ├── caching/               ← D1, D2 evidence
        ├── load-balancing/        ← B2 evidence
        └── failure-demo/          ← D3 evidence
```

---

## 🚀 Running the Project

### Prerequisites
```bash
# All Macs
brew install python3     # Mac 3 & 4 (backends)
brew install dnsmasq     # Mac 1 (DNS)
brew install nginx       # Mac 2 (reverse proxy)
```

---

### Backend A — Mac 3 (Kabir)
```bash
cd backend-a
python3 server.py
# 🚀 Backend Server A running on http://0.0.0.0:3001
```

### Backend B — Mac 4 (Ayush)
```bash
cd backend-b
python3 server.py
# 🚀 Backend Server B running on http://0.0.0.0:3002
```

---

### DNS Server — Mac 1 (Hardik)
```bash
# Copy config
cp configs/dnsmasq/dnsmasq.conf /opt/homebrew/etc/dnsmasq.conf

# Start
sudo brew services restart dnsmasq

# Verify
dig @10.7.7.36 app.Kuch_Nahi.test
# ANSWER SECTION: 10.7.19.243
```

**Configure client Macs (Mac 2, 3, 4) to use Mac 1 DNS:**
```bash
sudo networksetup -setdnsservers "Wi-Fi" 10.7.7.36
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
```

---

### nginx — Mac 2 (Abuzar)
```bash
# Generate TLS certificate first (see configs/tls/server.cnf for full steps)
mkdir -p ~/cn-project/certs && cd ~/cn-project/certs
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt \
  -subj "/C=IN/ST=Delhi/L=Delhi/O=CN-Project/CN=CN Project Root CA"
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -config /path/to/configs/tls/server.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 -sha256 -extensions req_ext -extfile /path/to/configs/tls/server.cnf

# Trust CA on all Macs (AirDrop ca.crt, then run on each)
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ~/Downloads/ca.crt

# Copy nginx config (update ssl_certificate paths to your username!)
cp configs/nginx/nginx.conf /opt/homebrew/etc/nginx/nginx.conf
nginx -t            # syntax check
brew services restart nginx
sudo lsof -nP -iTCP:8443 -sTCP:LISTEN   # verify listening
```

---

## 🔬 Testing Commands

### A3 — DNS resolution (from Mac 3 or Mac 4)
```bash
dig app.Kuch_Nahi.test
# ✅ ANSWER: 10.7.19.243  |  SERVER: 10.7.7.36#53
```

### A4 — Prove it's a private domain
```bash
dig @8.8.8.8 app.Kuch_Nahi.test
# ✅ status: NXDOMAIN  (Google DNS doesn't know this domain)
```

### A5 — Pairwise pings
```bash
# Mac 1 → others
ping -c 4 10.7.19.243 && ping -c 4 10.7.21.89 && ping -c 4 10.7.24.95
```

### B1 — HTTPS proof (⚠️ NO `-k` flag)
```bash
curl -v https://app.Kuch_Nahi.test:8443/
# ✅ TLSv1.2/1.3, subjectAltName matched, HTTP/1.1 200 OK
```

### B2 — Load balancing (6 requests)
```bash
for i in {1..6}; do
  echo "===== REQUEST $i ====="
  curl -sD - https://app.Kuch_Nahi.test:8443/api/status -o /dev/null \
    | grep -i '^X-Backend:'
done
# ✅ Alternating: X-Backend: A  /  X-Backend: B
```

### D1 — HTTP caching headers
```bash
curl -sI https://app.Kuch_Nahi.test:8443/api/status
# ✅ Cache-Control: max-age=60, ETag: "backend-a-v1", Date: ...

# 304 Not Modified demo
curl -i -H 'If-None-Match: "backend-a-v1"' https://app.Kuch_Nahi.test:8443/api/status
# ✅ HTTP/1.0 304 Not Modified
```

### D3 — Failure demo (Option A: stop Backend A)
```bash
# BEFORE: show A + B
for i in {1..4}; do curl -sD - https://app.Kuch_Nahi.test:8443/api/status -o /dev/null | grep -i '^X-Backend:'; done

# ACTION: kill Backend A on Mac 3 (Ctrl+C or pkill -f "python3 server.py")

# AFTER: only B
for i in {1..4}; do curl -sD - https://app.Kuch_Nahi.test:8443/api/status -o /dev/null | grep -i '^X-Backend:'; done

# RESTORE: restart Backend A on Mac 3
cd backend-a && python3 server.py
```

---

## 📋 Evidence Screenshot Checklist

| ID | Evidence | Command / Source |
|----|----------|-----------------|
| **A1** | Machine IPs, roles, interface | `networksetup -getinfo "Wi-Fi"` on all 4 Macs |
| **A2** | dnsmasq config (key lines) | `grep -E '^(listen|bind|no-resolv|server=|address=|local-ttl)' dnsmasq.conf` |
| **A3** | `dig app.Kuch_Nahi.test` from client | Shows SERVER=10.7.7.36 and ANSWER=10.7.19.243 |
| **A4** | `dig @8.8.8.8 app.Kuch_Nahi.test` | Shows NXDOMAIN |
| **A5** | All 6 pairwise pings | 0% packet loss on all 6 pairs |
| **B1** | `curl -v https://app.Kuch_Nahi.test:8443/` | TLS handshake + HTTP 200, no `-k` |
| **B2** | 6 load-balanced requests | Alternating X-Backend: A / B |
| **B3** | nginx config | upstream + listen 8443 ssl + proxy_pass |
| **C1** | Wireshark DNS | Filter: `dns` — UDP/53 query→response |
| **C2** | Wireshark TCP handshake | Filter: `tcp.flags.syn==1` — SYN→SYN-ACK→ACK |
| **C3** | Wireshark TLS handshake | Filter: `tls` — ClientHello→Certificate→AppData |
| **D1** | Cache-Control + ETag headers | `curl -sI` output |
| **D2** | Cache-Control explanation | Written answer in form |
| **D3** | Failure before/after/restore | Screenshots + video |

---

## 🔌 Port Reference

| Service | Protocol | Port | Machine |
|---------|----------|------|---------|
| DNS | UDP | 53 | Mac 1 — Hardik |
| HTTPS nginx | TCP | 8443 | Mac 2 — Abuzar |
| Backend A | TCP | 3001 | Mac 3 — Kabir |
| Backend B | TCP | 3002 | Mac 4 — Ayush |

---

## 🛠️ Troubleshooting

| Problem | Command to diagnose | Fix |
|---------|--------------------|----|
| DNS not resolving | `sudo lsof -nP -iUDP:53` | `sudo brew services restart dnsmasq` |
| HTTPS cert error | `curl -v ...` shows "certificate verify failed" | Re-run `sudo security add-trusted-cert ...` on client Mac |
| nginx won't start | `nginx -t` | Check ssl_certificate path matches your macOS username |
| Backend not responding | `sudo lsof -nP -iTCP:3001` | `cd backend-a && python3 server.py` |
| Internet breaks after DNS change | `dig @8.8.8.8 google.com` from Mac 1 | Ensure `server=8.8.8.8` is in dnsmasq.conf |

---

## 📚 References

- [dnsmasq Documentation](http://www.thekelleys.org.uk/dnsmasq/doc.html)
- [nginx Reverse Proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [OpenSSL req](https://www.openssl.org/docs/man1.1.1/man1/openssl-req.html)
- [HTTP Caching — RFC 7234](https://www.rfc-editor.org/rfc/rfc7234)
- [TLS 1.3 — RFC 8446](https://www.rfc-editor.org/rfc/rfc8446)
- [Wireshark Display Filters](https://wiki.wireshark.org/DisplayFilters)

---

<div align="center">
  <sub>Computer Networks Course Project · Rishihood University · 2026</sub>
</div>
