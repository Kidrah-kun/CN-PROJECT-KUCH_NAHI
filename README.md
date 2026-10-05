# 🌐 Private Network Service Platform
### Computer Networks Course Project — CN Phase 1 & 2

<div align="center">

![Network](https://img.shields.io/badge/Project-Computer%20Networks-blue?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey?style=for-the-badge&logo=apple)
![DNS](https://img.shields.io/badge/DNS-dnsmasq-green?style=for-the-badge)
![Proxy](https://img.shields.io/badge/Proxy-nginx%20%2B%20TLS-red?style=for-the-badge)
![Backend](https://img.shields.io/badge/Backend-Python%20REST-yellow?style=for-the-badge)

**Domain:** `app.Kuch_Nahi.test` | **Institution:** Rishihood University

</div>

---

## 👥 Team Members

| # | Name | Role | Machine | Private IP | Interface |
|---|------|------|---------|-----------|-----------|
| 1 | **Hardik Hathwal** (Kidrah) | DNS Server + Client | Mac 1 | `10.7.7.36` | `en0` |
| 2 | **Abuzar Haider** | Nginx HTTPS Reverse Proxy / Load Balancer | Mac 2 | `10.7.19.243` | `en0` |
| 3 | **Kabir Sharma** | Backend Server A | Mac 3 | `10.7.21.89` | `en0` |
| 4 | **Ayush Tiwari** | Backend Server B + Client | Mac 4 | `10.7.24.95` | `en0` |

**Network:** iPhone Hotspot LAN · **Subnet:** `10.7.0.0/19` (255.255.224.0) · **Gateway:** `10.7.0.1`

---

## 🏗️ Architecture

```
                        iPhone Hotspot LAN
         ┌──────────────────────────────────────────────────┐
         │                                                  │
         │  Mac 1 — Hardik              Mac 2 — Abuzar      │
         │  Private DNS Server          nginx Edge Server   │
         │  dnsmasq — UDP 53            HTTPS — TCP 8443    │
         │  10.7.7.36                   10.7.19.243         │
         │      │                           │               │
         │      │ app.Kuch_Nahi.test        │               │
         │      │ → 10.7.19.243            │               │
         │      │                    ┌──────┴──────┐        │
         │      │                    │             │        │
         │  Mac 3 — Kabir       Mac 4 — Ayush              │
         │  Backend A           Backend B + Client         │
         │  Python REST         Python REST + curl         │
         │  TCP :3001           TCP :3002                  │
         │  10.7.21.89          10.7.24.95                 │
         └──────────────────────────────────────────────────┘

Full Request Flow:
─────────────────
  Client (Mac 3 or Mac 4)
       │
       ▼ dig app.Kuch_Nahi.test
  Mac 1 — dnsmasq (UDP 53)
       │ returns 10.7.19.243
       ▼
  Mac 2 — nginx (TCP 8443, TLS)
       │ Round-robin load balance
       ├──────────────────────────────────────┐
       ▼                                      ▼
  Mac 3 — Backend A (TCP 3001)    Mac 4 — Backend B (TCP 3002)
  X-Backend: A                    X-Backend: B
```

### OSI / Protocol Layer Mapping

| Layer | Protocol | Component |
|-------|----------|-----------|
| Application | DNS, HTTP, REST | dnsmasq, nginx, Python API |
| Session / Transport | TLS 1.2/1.3 | nginx SSL termination |
| Transport | TCP (8443, 3001, 3002), UDP (53) | Sockets |
| Network | IP (10.7.x.x / 19) | iPhone Hotspot LAN |
| Data Link | Ethernet/Wi-Fi | en0 |

---

## 📁 Repository Structure

```
Kuch_Nahi/
│
├── README.md                        ← You are here
├── CN_Project_Doc.pdf               ← Original project specification
│
├── backend-a/
│   └── server.py                    ← Backend A (Mac 3, port 3001)
│
├── backend-b/
│   └── server.py                    ← Backend B (Mac 4, port 3002)
│
├── configs/
│   ├── dnsmasq/
│   │   ├── dnsmasq.conf             ← Mac 1 primary DNS config
│   │   └── dnsmasq-backup-mac4.conf ← Mac 4 backup DNS (Phase 2)
│   ├── nginx/
│   │   └── nginx.conf               ← Mac 2 reverse proxy + LB config
│   ├── tls/
│   │   └── server.cnf               ← OpenSSL SAN config for TLS cert
│   └── firewall/
│       └── pf-rules.sh              ← Phase 2 service isolation (pf)
│
├── docs/
│   └── phase2-report.md             ← Phase 2 resilience & learning summary
│
├── scripts/
│   └── quick-test.sh                ← Full-stack test from any client Mac
│
└── evidence/                        ← Screenshots & Wireshark captures
    ├── wireshark/                   ← .pcapng files
    └── screenshots/
        ├── dns/                     ← A2, A3, A4 evidence
        ├── ping/                    ← A5 evidence
        ├── tcp/                     ← C2 Wireshark
        ├── tls/                     ← C3 Wireshark
        ├── caching/                 ← D1, D2 evidence
        ├── load-balancing/          ← B2 evidence
        └── failure-demo/            ← D3 evidence
```

---

## 🚀 Phase 1 — Setup & Run

### Prerequisites (all Macs)
```bash
# Verify Homebrew is installed
brew --version

# Install Python (Mac 3 & Mac 4)
brew install python3

# Install dnsmasq (Mac 1, and Mac 4 for Phase 2 backup)
brew install dnsmasq

# Install nginx (Mac 2)
brew install nginx
```

---

### Step 1 — Verify LAN Connectivity (Task A)

Run pairwise pings **before** configuring anything else:

```bash
# Mac 1 (Hardik) → all others
ping -c 4 10.7.19.243  # → Mac 2
ping -c 4 10.7.21.89   # → Mac 3
ping -c 4 10.7.24.95   # → Mac 4

# Mac 2 (Abuzar) → all others
ping -c 4 10.7.7.36    # → Mac 1
ping -c 4 10.7.21.89   # → Mac 3
ping -c 4 10.7.24.95   # → Mac 4

# Mac 3 (Kabir) → all others
ping -c 4 10.7.7.36    # → Mac 1
ping -c 4 10.7.19.243  # → Mac 2
ping -c 4 10.7.24.95   # → Mac 4

# Mac 4 (Ayush) → all others
ping -c 4 10.7.7.36    # → Mac 1
ping -c 4 10.7.19.243  # → Mac 2
ping -c 4 10.7.21.89   # → Mac 3
```

**Expected:** `4 packets transmitted, 4 packets received, 0.0% packet loss` for all pairs.

📸 **Screenshot A5** — capture all 6 ping results.

---

### Step 2 — DNS Server Setup — Mac 1 (Task B)

```bash
# On Mac 1 — Hardik

# Copy config
cp configs/dnsmasq/dnsmasq.conf /opt/homebrew/etc/dnsmasq.conf

# Test syntax
sudo /opt/homebrew/opt/dnsmasq/sbin/dnsmasq --test
# Expected: "dnsmasq: syntax check OK"

# Start service
sudo brew services restart dnsmasq

# Verify listening on UDP 53
sudo lsof -nP -iUDP:53

# Quick local test
dig @10.7.7.36 app.Kuch_Nahi.test
# Expected: ANSWER SECTION → 10.7.19.243
```

📸 **Screenshot A2** — show dnsmasq config output:
```bash
grep -E '^(listen-address|bind-interfaces|no-resolv|server=|address=|local-ttl)' \
  /opt/homebrew/etc/dnsmasq.conf
```

---

### Step 3 — Configure Client Macs to Use Mac 1 DNS

Run on **Mac 2, Mac 3, and Mac 4**:
```bash
sudo networksetup -setdnsservers "Wi-Fi" 10.7.7.36

# Flush DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Verify
networksetup -getdnsservers "Wi-Fi"
# Expected: 10.7.7.36
```

---

### Step 4 — Verify DNS Evidence

```bash
# A3 — Run from Mac 3 or Mac 4 (NOT Mac 1)
dig app.Kuch_Nahi.test
# ANSWER SECTION: 10.7.19.243
# SERVER: 10.7.7.36#53  ← proves it uses Mac 1 DNS

# A4 — Prove it's private (not in public DNS)
dig @8.8.8.8 app.Kuch_Nahi.test
# Expected: status: NXDOMAIN
```

📸 **Screenshot A3** — full `dig` output  
📸 **Screenshot A4** — full `dig @8.8.8.8` output showing NXDOMAIN

---

### Step 5 — Backend Server A — Mac 3 (Kabir)

```bash
# On Mac 3
cd backend-a
python3 server.py
# 🚀 Backend Server A running on http://0.0.0.0:3001

# Test locally
curl -i http://127.0.0.1:3001/api/status

# Test from Mac 2
curl -i http://10.7.21.89:3001/api/status
# Expected headers: X-Backend: A, Cache-Control: max-age=60
```

---

### Step 6 — Backend Server B — Mac 4 (Ayush)

```bash
# On Mac 4
cd backend-b
python3 server.py
# 🚀 Backend Server B running on http://0.0.0.0:3002

# Test locally
curl -i http://127.0.0.1:3002/api/status

# Test from Mac 2
curl -i http://10.7.24.95:3002/api/status
# Expected headers: X-Backend: B, Cache-Control: max-age=60
```

---

### Step 7 — TLS Certificate — Mac 2 (Abuzar)

```bash
# On Mac 2
mkdir -p ~/cn-project/certs && cd ~/cn-project/certs

# Create CA
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 \
  -out ca.crt \
  -subj "/C=IN/ST=Delhi/L=Delhi/O=CN-Project/OU=KuchNahi/CN=CN Project Root CA"

# Create server key and CSR
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr \
  -config ~/path/to/configs/tls/server.cnf

# Sign the certificate
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out server.crt -days 365 -sha256 \
  -extensions req_ext -extfile ~/path/to/configs/tls/server.cnf

# Verify SAN
openssl x509 -in server.crt -text -noout | grep -A2 "Subject Alternative"
```

**Trust CA on ALL Macs** (AirDrop `ca.crt` then run on each):
```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ~/Downloads/ca.crt
```

---

### Step 8 — nginx Reverse Proxy — Mac 2 (Abuzar)

```bash
# On Mac 2

# Copy config (update ssl_certificate paths first!)
cp configs/nginx/nginx.conf /opt/homebrew/etc/nginx/nginx.conf

# Edit to replace YOUR_USERNAME with Abuzar's macOS username
nano /opt/homebrew/etc/nginx/nginx.conf

# Test syntax
nginx -t
# Expected: "syntax is ok" and "test is successful"

# Start nginx
brew services restart nginx

# Verify listening on port 8443
sudo lsof -nP -iTCP:8443 -sTCP:LISTEN
```

📸 **Screenshot B3** — show nginx config:
```bash
cat /opt/homebrew/etc/nginx/nginx.conf
```

---

### Step 9 — HTTPS & Load Balancing Tests

**B1 — HTTPS proof** (run from Mac 3 or Mac 4):
```bash
# ⚠️ DO NOT USE -k (the form forbids it — -k bypasses TLS validation)
curl -v https://app.Kuch_Nahi.test:8443/
```
Expected output includes:
- `TLSv1.2` or `TLSv1.3`
- `subjectAltName: host "app.Kuch_Nahi.test" matched`
- `HTTP/1.1 200 OK`

📸 **Screenshot B1** — full `curl -v` output

**B2 — Load balancing proof** (6 requests):
```bash
for i in {1..6}; do
    echo "===== REQUEST $i ====="
    curl -sD - https://app.Kuch_Nahi.test:8443/api/status -o /dev/null \
      | grep -i '^X-Backend:'
done
```
Expected: alternating `X-Backend: A` and `X-Backend: B`

📸 **Screenshot B2** — all 6 requests

---

### Step 10 — Wireshark Captures (Task G)

Open Wireshark on Mac 4, select interface `en0`.

**C1 — DNS capture:**
```bash
# Wireshark filter: dns
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
dig app.Kuch_Nahi.test
```
📸 **Screenshot C1** — show DNS query (Mac4→Mac1 UDP/53) and response (MAC2 IP + TTL)

**C2 — TCP 3-way handshake:**
```bash
# Wireshark filter: tcp.flags.syn == 1
curl -v https://app.Kuch_Nahi.test:8443/
```
📸 **Screenshot C2** — show SYN → SYN-ACK → ACK packets with ports

**C3 — TLS handshake:**
```bash
# Wireshark filter: tls
curl -v https://app.Kuch_Nahi.test:8443/
```
📸 **Screenshot C3** — show ClientHello, ServerHello, Certificate, ChangeCipherSpec, Application Data

---

### Step 11 — HTTP Caching (Task F)

**D1 — Cache-Control headers:**
```bash
curl -sI https://app.Kuch_Nahi.test:8443/api/status
# Expected: Cache-Control: max-age=60, ETag: "backend-a-v1", X-Backend: A/B
```

**304 Not Modified demo:**
```bash
# First request to get ETag
curl -sD - https://app.Kuch_Nahi.test:8443/api/status -o /dev/null

# Conditional request (use actual ETag value from above)
curl -i -H 'If-None-Match: "backend-a-v1"' https://app.Kuch_Nahi.test:8443/api/status
# Expected: HTTP/1.0 304 Not Modified
```

📸 **Screenshot D1** — headers with Cache-Control, ETag, Date, X-Backend

**D2 — Explanation:**
> `Cache-Control: max-age=60` tells the client the response can be considered fresh for 60 seconds. During this window, the client reuses the cached response without contacting the server. After 60 seconds, the client must revalidate. With an `ETag`, it sends `If-None-Match`; if unchanged, the server responds with `304 Not Modified` (no body), saving bandwidth.

---

### Step 12 — Failure Demonstration (Task F / D3)

> **Option A** — Stop Backend A, prove service continues via Backend B.

```bash
# Record video of this entire sequence!

# BEFORE — Prove both backends work
for i in {1..6}; do
    echo "REQUEST $i:"
    curl -sD - https://app.Kuch_Nahi.test:8443/api/status -o /dev/null \
      | grep -i '^X-Backend:'
done
# Expected: A, B, A, B, A, B

# ACTION — Kill Backend A (on Mac 3)
pkill -f "python3 server.py"   # or Ctrl+C in terminal

# AFTER — Prove service continues
for i in {1..6}; do
    echo "REQUEST $i:"
    curl -sD - https://app.Kuch_Nahi.test:8443/api/status -o /dev/null \
      | grep -i '^X-Backend:'
done
# Expected: B, B, B, B, B, B  ← only Backend B

# RESTORE — Restart Backend A (on Mac 3)
cd ~/cn-project/backend-a && python3 server.py

# VERIFY RESTORE
for i in {1..4}; do
    echo "REQUEST $i:"
    curl -sD - https://app.Kuch_Nahi.test:8443/api/status -o /dev/null \
      | grep -i '^X-Backend:'
done
# Expected: A and B alternating again
```

📸 **Screenshot D3** — Before, After, and After-restore states  
🎥 **Video** — record the entire D3 sequence

---

## 🔒 Phase 2 — Hardening & Resilience

### Extension A — Backup DNS (Mac 4)

```bash
# On Mac 4
cp configs/dnsmasq/dnsmasq-backup-mac4.conf /opt/homebrew/etc/dnsmasq.conf
sudo brew services start dnsmasq

# Configure all clients with BOTH DNS servers
sudo networksetup -setdnsservers "Wi-Fi" 10.7.7.36 10.7.24.95

# Test failover: stop primary DNS on Mac 1
# (On Mac 1): sudo brew services stop dnsmasq

# Then on client:
dig app.Kuch_Nahi.test
# Still resolves → 10.7.19.243 via backup on Mac 4
```

### Extension B — DNS TTL Behavior

```bash
# With local-ttl=30 in dnsmasq.conf:
dig app.Kuch_Nahi.test   # TTL = 30

# Change record (Mac 1 dnsmasq.conf):
# address=/app.Kuch_Nahi.test/10.7.21.89   ← temporary different IP

sudo brew services restart dnsmasq

# Immediately after restart — client may still see cached old IP
dig app.Kuch_Nahi.test

# After 30 seconds — new IP appears
dig app.Kuch_Nahi.test

# Force flush
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
```

### Extension C — Service Isolation (Firewall)

```bash
# See configs/firewall/pf-rules.sh for full instructions.
# Goal: only Mac 2 (nginx) can reach backends directly.

# Test from Mac 2 (nginx) → should SUCCEED:
curl http://10.7.21.89:3001/api/status   # → 200 OK
curl http://10.7.24.95:3002/api/status   # → 200 OK

# Test from Mac 4 (client) → should FAIL:
curl --connect-timeout 5 http://10.7.21.89:3001/api/status  # → timeout
```

### Extension D — HA Failover Behavior

The current design has **Mac 2 as a single point of failure** (the nginx edge).
nginx's `max_fails` and `proxy_next_upstream` handle backend HA automatically.

To demonstrate full HA, a standby nginx on Mac 3 with DNS cutover shows edge-level resilience.

---

## 🗺️ Network Topology Diagram

```
                      ┌─────────────────────────────────┐
                      │       iPhone Hotspot LAN         │
                      │       10.7.0.0/19                │
                      │       Gateway: 10.7.0.1          │
                      └─────────────────────────────────┘
                                      │
              ┌───────────────────────┼───────────────────────┐
              │                       │                       │
     ┌────────┴────────┐   ┌─────────┴────────┐   ┌─────────┴────────┐
     │   Mac 1         │   │   Mac 2           │   │ Mac 3    Mac 4   │
     │   Hardik        │   │   Abuzar          │   │ Kabir    Ayush   │
     │   10.7.7.36     │   │   10.7.19.243     │   │ 10.7.21.89       │
     │   DNS/dnsmasq   │   │   nginx+TLS       │   │ :3001    :3002   │
     │   UDP :53       │   │   TCP :8443       │   │ Backend A&B      │
     └────────┬────────┘   └─────────┬────────┘   └─────────┬────────┘
              │  ① DNS Query          │ ③ HTTPS               │
              │  app.Kuch_Nahi.test   │                       │
              │◄──────────────────────│                       │
              │  ② Returns 10.7.19.243│  ④ proxy_pass         │
              │                       │──────────────────────►│
              │                       │  X-Backend: A or B    │
```

---

## 📋 Evidence Checklist

| ID | Evidence Required | Screenshot/Output |
|----|------------------|------------------|
| A1 | Machine IPs, roles, interface info | 4x `networksetup -getinfo "Wi-Fi"` |
| A2 | dnsmasq config (key lines) | `grep` of dnsmasq.conf |
| A3 | `dig app.Kuch_Nahi.test` from client | Full dig output, SERVER=10.7.7.36 |
| A4 | `dig @8.8.8.8 app.Kuch_Nahi.test` → NXDOMAIN | Full dig output |
| A5 | All 6 pairwise ping results | All 0% packet loss |
| B1 | `curl -v https://app.Kuch_Nahi.test:8443/` (no -k) | TLS + HTTP 200 |
| B2 | 6 load-balanced requests | Alternating X-Backend: A / B |
| B3 | nginx config | upstream + server + ssl + proxy_pass |
| C1 | Wireshark DNS | UDP/53, query→response, TTL |
| C2 | Wireshark TCP handshake | SYN→SYN-ACK→ACK |
| C3 | Wireshark TLS handshake | ClientHello→Certificate→AppData |
| D1 | curl `-sI` headers | Cache-Control, ETag, Date, X-Backend |
| D2 | Cache-Control explanation | Written answer |
| D3 | Failure demo (before/after/restore) | Screenshots + Video |

---

## 🔌 Port Reference

| Service | Protocol | Port | Machine | Assigned To |
|---------|----------|------|---------|-------------|
| DNS | UDP | 53 | Mac 1 | Hardik Hathwal |
| HTTPS (nginx) | TCP | 8443 | Mac 2 | Abuzar Haider |
| Backend A | TCP | 3001 | Mac 3 | Kabir Sharma |
| Backend B | TCP | 3002 | Mac 4 | Ayush Tiwari |

---

## 🔧 Troubleshooting

### DNS not resolving
```bash
# Check dnsmasq is running
sudo lsof -nP -iUDP:53

# Restart
sudo brew services restart dnsmasq

# Test from Mac 1 itself
dig @127.0.0.1 app.Kuch_Nahi.test
```

### HTTPS returns certificate error
```bash
# Ensure CA is trusted on the client Mac
security find-certificate -c "CN Project Root CA" /Library/Keychains/System.keychain

# Re-trust if needed
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ~/Downloads/ca.crt
```

### nginx won't start
```bash
# Check syntax
nginx -t

# Check if port 8443 is already in use
sudo lsof -nP -iTCP:8443
```

### Backend not responding
```bash
# Check it's listening
sudo lsof -nP -iTCP:3001   # Mac 3
sudo lsof -nP -iTCP:3002   # Mac 4

# Restart
cd backend-a && python3 server.py
```

---

## 📊 Marks Breakdown

| Area | Marks | Tasks |
|------|-------|-------|
| LAN Setup + Private DNS (Task A + B) | 10 | A1–A5 |
| HTTP/REST Backends + Reverse Proxy + LB (Task C + D) | 10 | B1–B3 |
| HTTPS / TLS Correctness (Task E) | 8 | B1, C3 |
| Packet Analysis (Task G) | 7 | C1–C3 |
| HTTP Caching (Task F) | 5 | D1–D3 |
| Individual Viva Phase 1 | 10 | — |
| **Phase 1 Total** | **50** | |
| Phase 2 Resilience & HA Failover | 15 | Ext. A, B, D |
| Service Isolation & Edge Migration | 10 | Ext. C, E |
| Troubleshooting Challenge | 10 | Ext. F |
| Final Report | 5 | docs/ |
| Individual Viva Phase 2 | 10 | — |
| **Phase 2 Total** | **50** | |
| **Grand Total** | **100** | |

---

## 📚 References

- [dnsmasq Documentation](http://www.thekelleys.org.uk/dnsmasq/doc.html)
- [nginx Reverse Proxy Guide](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [OpenSSL Certificate Guide](https://www.openssl.org/docs/man1.1.1/man1/openssl-req.html)
- [macOS networksetup Man Page](https://ss64.com/osx/networksetup.html)
- [Wireshark Display Filters](https://wiki.wireshark.org/DisplayFilters)
- [HTTP Caching — RFC 7234](https://www.rfc-editor.org/rfc/rfc7234)
- [TLS 1.3 — RFC 8446](https://www.rfc-editor.org/rfc/rfc8446)

---

<div align="center">
  <sub>Computer Networks Course Project · Rishihood University · 2026</sub>
</div>
