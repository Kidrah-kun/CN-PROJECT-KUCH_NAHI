# Setup Notes — Configuration Bundle

> Complete step-by-step instructions for reproducing the CN project environment.

---

## 1. Prerequisites

All Macs must be on the **same private LAN** (university Wi-Fi or lab switch).  
Verify connectivity: `ping <other-mac-ip>` from each machine.

**Required software:**
- `dnsmasq` — `brew install dnsmasq` (Mac 1 + Mac 4)
- `nginx` — `brew install nginx` (Mac 2 + Mac 3)
- Python 3 — built-in on macOS (Mac 3 + Mac 4)
- OpenSSL — `brew install openssl` (Mac 2 for TLS)

---

## 2. DNS Setup (Mac 1 — Hardik, 10.7.6.152)

### 2a. Install and configure dnsmasq

```bash
brew install dnsmasq

# Copy config
sudo cp configs/dnsmasq.conf /usr/local/etc/dnsmasq.conf

# Start dnsmasq
sudo brew services start dnsmasq
# OR for one-shot:
sudo dnsmasq --conf-file=/usr/local/etc/dnsmasq.conf --no-daemon
```

**Key entries in `dnsmasq.conf`:**
```
address=/app.Kuch_Nahi.test/10.7.31.75
address=/api.Kuch_Nahi.test/10.7.31.75
local=/test/
domain=Kuch_Nahi.test
```

### 2b. Point clients to this DNS

On each client Mac:
```
System Settings → Network → Wi-Fi → Details → DNS
Add: 10.7.6.152
```
Or via terminal:
```bash
sudo networksetup -setdnsservers "Wi-Fi" 10.7.6.152
```

### 2c. Verify DNS

```bash
dig app.Kuch_Nahi.test @10.7.6.152
# Should show: ;; ANSWER SECTION: ... 10.7.31.75
```

---

## 3. TLS Certificate Setup (Mac 2 — Abuzar, 10.7.31.75)

### 3a. Generate Root CA

```bash
# Generate CA key and self-signed certificate
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 365 -key ca.key -out ca.crt \
  -subj "/C=IN/ST=Delhi/O=KuchNahi/CN=KuchNahi-CA"
```

### 3b. Generate Server Certificate with SAN

```bash
# Using the server.cnf config (see configs/tls/server.cnf)
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -config configs/tls/server.cnf
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out server.crt -extensions v3_req -extfile configs/tls/server.cnf
```

### 3c. Trust the CA on each Mac

```bash
# macOS Keychain (on each client Mac):
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt

# OR pass via curl:
curl --cacert ~/Downloads/ca.crt https://app.Kuch_Nahi.test:8443/
```

> **Important:** macOS system curl (`/usr/bin/curl`) may still prefer the system keychain.  
> Always use: `/usr/bin/curl --cacert ~/Downloads/ca.crt <url>`

---

## 4. nginx Setup (Mac 2 — Abuzar, 10.7.31.75)

```bash
# Copy config
sudo cp configs/nginx.conf /usr/local/etc/nginx/nginx.conf

# Test config
sudo nginx -t

# Start nginx
sudo nginx

# Reload after changes
sudo nginx -s reload
```

**Key nginx config sections:**

```nginx
upstream backends {
    server 10.7.11.100:3001;   # Backend A (Kabir)
    server 10.7.15.153:3002;   # Backend B (Ayush)
}

server {
    listen 8443 ssl;
    server_name app.Kuch_Nahi.test api.Kuch_Nahi.test;
    ssl_certificate     /path/to/server.crt;
    ssl_certificate_key /path/to/server.key;
    
    location / {
        proxy_pass http://backends;
        add_header X-Backend $upstream_addr always;
        add_header Cache-Control "max-age=60" always;
    }
}
```

---

## 5. Backend A (Mac 3 — Kabir, 10.7.11.100)

```bash
# Navigate to backend directory
cd /path/to/CN-PROJECT-KUCH_NAHI-main/backend-a

# Install dependencies (if any)
pip3 install flask   # or: python3 -m pip install flask

# Start Backend A on port 3001
python3 server.py
# OR with explicit host/port:
python3 -c "from server import app; app.run(host='0.0.0.0', port=3001)"
```

**Verify:**
```bash
curl http://10.7.11.100:3001/
# Should return JSON with "backend": "A"
```

---

## 6. Backend B (Mac 4 — Ayush, 10.7.15.153)

```bash
# Navigate to backend directory
cd /path/to/CN-PROJECT-KUCH_NAHI-main/backend-b

# Start Backend B on port 3002
python3 server.py
```

**Verify:**
```bash
curl http://10.7.15.153:3002/
# Should return JSON with "backend": "B"
```

---

## 7. Backup DNS (Mac 4 — Ayush, 10.7.15.153)

```bash
brew install dnsmasq

# Use the backup dnsmasq config
sudo dnsmasq --conf-file=configs/phase2/backup-dnsmasq.conf --no-daemon
# OR copy to /usr/local/etc/dnsmasq.conf and start service
```

**To use backup DNS on a client:**
```bash
sudo networksetup -setdnsservers "Wi-Fi" 10.7.15.153
# verify:
dig app.Kuch_Nahi.test
# SERVER should show 10.7.15.153
```

---

## 8. Standby nginx Edge (Mac 3 — Kabir, 10.7.11.100)

```bash
# Copy standby config
sudo cp configs/phase2/standby-nginx.conf /usr/local/etc/nginx/nginx.conf
sudo nginx -t && sudo nginx

# This standby adds: add_header X-Edge "standby-mac3" always;
# DNS cutover: change dnsmasq to point app.Kuch_Nahi.test → 10.7.11.100
# After TTL=30s, clients automatically hit the standby edge
```

---

## 9. Firewall Rules — pf (Mac 3 + Mac 4)

### Setup (block direct port access, allow only from nginx/edge)

**Mac 3 (Kabir) — protect port 3001:**
```bash
# Backup original rules
sudo cp /etc/pf.conf ~/pf.conf.backup

# Apply custom rules
cat > ~/cn-extra.rules <<'EOF'
pass in quick on lo0 all
pass in quick proto tcp from 10.7.31.75 to any port 3001
block in quick proto tcp from any to any port 3001
EOF

cat /etc/pf.conf ~/cn-extra.rules > ~/pf-cn.conf
sudo pfctl -f ~/pf-cn.conf
sudo pfctl -E
```

**Mac 4 (Ayush) — protect port 3002:**
```bash
sudo cp /etc/pf.conf ~/pf.conf.backup
cat > ~/cn-extra.rules <<'EOF'
pass in quick on lo0 all
pass in quick proto tcp from 10.7.31.75 to any port 3002
block in quick proto tcp from any to any port 3002
EOF
cat /etc/pf.conf ~/cn-extra.rules > ~/pf-cn.conf
sudo pfctl -f ~/pf-cn.conf
sudo pfctl -E
```

### Teardown / Restore

```bash
# Restore original rules and disable pf
sudo pfctl -f ~/pf.conf.backup
sudo pfctl -d
```

### Verify Tokens
After `pfctl -E`, the token is printed. Record it:
- Kabir token: `6342856708590256387`
- Ayush token: `11243875211577960873`

---

## 10. End-to-End Test

```bash
# From any Mac client (with DNS pointing to 10.7.6.152):
/usr/bin/curl -s --cacert ~/Downloads/ca.crt https://app.Kuch_Nahi.test:8443/ | python3 -m json.tool

# Check load balancing (run several times):
for i in 1 2 3 4 5 6; do
  /usr/bin/curl -sI --cacert ~/Downloads/ca.crt https://app.Kuch_Nahi.test:8443/ | grep -i x-backend
done
# Expected: alternating A and B

# Check caching (304):
/usr/bin/curl -sI --cacert ~/Downloads/ca.crt https://app.Kuch_Nahi.test:8443/
# Second request should return 304 (ETag match)
```

---

*Setup Notes — Team Kuch Nahi, Nov 2026*

