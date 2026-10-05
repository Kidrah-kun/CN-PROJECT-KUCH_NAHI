# Phase 2 Final Report — Team Kuch_Nahi
## Computer Networks Project — Resilience, Hardening & Troubleshooting

**Team:** Kuch_Nahi | **Domain:** `app.Kuch_Nahi.test`

---

## What Changed from Phase 1

Phase 1 built the complete private network service platform:
- Private DNS (Mac 1), HTTPS nginx edge (Mac 2), Backend A (Mac 3), Backend B (Mac 4)
- TLS-terminated HTTPS, round-robin load balancing, HTTP caching headers

Phase 2 added **resilience layers** on top of the same infrastructure without rebuilding:
- **Backup DNS** on Mac 4 (Extension A)
- **DNS TTL behavior** demonstrated with 30s TTL (Extension B)
- **Backend firewall isolation** using macOS `pf` rules (Extension C)
- **HA failover** through `proxy_next_upstream` and DNS-based edge cutover (Extension D/E)

---

## Extension A — Backup DNS Resolver

### What we implemented
Ran a second `dnsmasq` instance on Mac 4 (10.7.24.95) with identical DNS records.
Configured all client Macs to list **both** DNS servers:
```bash
sudo networksetup -setdnsservers "Wi-Fi" 10.7.7.36 10.7.24.95
```

### Test results
1. Stopped `dnsmasq` on Mac 1 (`sudo brew services stop dnsmasq`)
2. Client `dig app.Kuch_Nahi.test` still resolved to `10.7.19.243` via Mac 4
3. HTTP requests continued successfully through nginx

### Learning
A **DNS service failure** (no nameserver responds) stops all name resolution — clients get `SERVFAIL` and cannot reach the service even if nginx and backends are healthy. A **DNS-backed failover** keeps the resolution layer working even when the primary nameserver is unavailable. This is why production systems use multiple DNS resolvers (e.g., Route 53 health checks with failover routing).

---

## Extension B — DNS TTL and Controlled Record Change

### What we implemented
Changed `local-ttl` to `30` seconds in both `dnsmasq` configs. Temporarily updated the `app.Kuch_Nahi.test` record from `10.7.19.243` (Mac 2) to `10.7.21.89` (Mac 3) to simulate a DNS record migration.

### Test results
1. Client resolves → gets `10.7.19.243`, TTL=30
2. Change record to `10.7.21.89`, restart dnsmasq
3. Immediately after → client still gets **old cached** `10.7.19.243` (TTL not expired)
4. After 30 seconds → client gets **new** `10.7.21.89`
5. Manual flush (`sudo dscacheutil -flushcache`) → immediate new answer

### Learning
TTL is the mechanism that controls how long a change takes to propagate globally. Production DNS migrations lower TTL well before the cutover (e.g., to 60s), make the change, then restore TTL. This balances caching efficiency (high TTL) against migration agility (low TTL).

---

## Extension C — Service Isolation (Backend Firewall Rules)

### What we implemented
Applied macOS `pf` firewall rules on Mac 3 and Mac 4:
- **Allow** inbound TCP connections to port 3001/3002 **only from Mac 2** (10.7.19.243)
- **Block** all other direct TCP access to backend ports

```
# Mac 3 pf anchor (port 3001)
pass in quick on en0 inet proto tcp from 10.7.19.243 to any port 3001 flags S/SA keep state
block in quick on en0 inet proto tcp from any to any port 3001
```

### Test results
- Mac 2 → Mac 3:3001: **✅ 200 OK** (nginx proxy path works)
- Mac 4 → Mac 3:3001: **❌ Connection timeout** (direct access blocked)

### Learning
Network-layer isolation ensures that even if an attacker gains access to the internal LAN, they cannot bypass the nginx reverse proxy (which provides TLS termination, access logging, rate limiting, etc.) and hit backends directly. This is the principle of **defense in depth** — multiple independent layers of security.

---

## Extension D — High-Availability Failover Behavior

### What we implemented
nginx's `proxy_next_upstream error timeout http_502 http_503 http_504;` with `max_fails=1 fail_timeout=5s` per backend provides **passive health checking**:
- First failed request to Backend A → nginx retries on Backend B
- After `fail_timeout`, Backend A is re-tested

### Test results
1. Backend A running: requests alternate A, B, A, B
2. Backend A killed: all requests route to B immediately
3. Backend A restarted: load balancing resumes (A and B alternate)

### Single point of failure identified
**Mac 2 (nginx edge)** is the current single point of failure. If Mac 2 goes down, no HTTPS requests can be served regardless of backend health. Eliminating this would require:
- A second nginx on a different machine
- DNS round-robin across both edge IPs, or
- A hardware/cloud load balancer above the nginx layer

---

## Extension E — DNS-Based Edge Migration

### What we implemented
Temporarily configured nginx on Mac 3, copied the same `nginx.conf` and TLS certificate. Updated `app.Kuch_Nahi.test` DNS record to point to Mac 3's IP. After TTL expiry, clients began hitting the new edge.

### Observation
Clients with the cached old TTL briefly continued hitting Mac 2 while clients with expired cache hit Mac 3. This TTL-based "soft cutover" window is predictable and manageable.

### Learning
DNS-based edge migration is how production systems perform **zero-downtime maintenance** on load balancers. The key steps are: (1) lower TTL ahead of time, (2) spin up new edge, (3) update DNS, (4) wait for propagation, (5) tear down old edge.

---

## Troubleshooting Methodology

When diagnosing network failures, we used a **bottom-up OSI approach**:

1. **Is the machine reachable?** → `ping`
2. **Does DNS resolve?** → `dig`, check `SERVER:` in output
3. **Does TCP connect?** → `curl -v`, Wireshark `tcp.flags.syn==1`
4. **Is TLS valid?** → `curl -v` (no -k), Wireshark `tls` filter
5. **Does the application respond?** → `curl -i`, check response headers

**Key insight:** Correct layer identification is critical. A symptom like "the website doesn't load" could be caused by any layer — a broken DNS server, a closed firewall port, an expired certificate, or a crashed backend process. Each layer requires different diagnostic tools.

---

*Report prepared by Team Kuch_Nahi — Rishihood University Computer Networks Course, 2026*
