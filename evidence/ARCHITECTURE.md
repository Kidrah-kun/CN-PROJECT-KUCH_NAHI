# Architecture Document — CN Project (Team: Kuch Nahi)

---

## 1. Topology Overview

```
         ┌─────────────────────────────────────────────────┐
         │              Private LAN (Wi-Fi / Ethernet)      │
         │                                                   │
         │  ┌──────────────┐      ┌──────────────────────┐  │
         │  │  Mac 1       │      │  Mac 2 (Abuzar)       │  │
         │  │  Hardik      │      │  10.7.31.75           │  │
         │  │  10.7.6.152  │◄────►│  nginx HTTPS Edge     │  │
         │  │  Primary DNS │      │  Port 8443            │  │
         │  │  (dnsmasq)   │      │  (Primary Edge)       │  │
         │  └──────────────┘      └──────────┬────────────┘  │
         │          ▲                        │               │
         │          │  DNS queries           │ Upstream proxy│
         │          │                        ▼               │
         │  ┌───────┴──────┐      ┌──────────────────────┐  │
         │  │  Mac 4       │      │  Mac 3 (Kabir)        │  │
         │  │  Ayush       │      │  10.7.11.100          │  │
         │  │  10.7.15.153 │      │  Backend A :3001      │  │
         │  │  Backup DNS  │      │  Standby Edge :8443   │  │
         │  │  Backend B   │      │  (pf firewall rules)  │  │
         │  │  Port 3002   │      └──────────────────────┘  │
         │  └──────────────┘                                 │
         └─────────────────────────────────────────────────-─┘
```

---

## 2. IP / MAC Address / Service Inventory

| Machine | Owner   | IP Address    | MAC Address (Wi-Fi)   | Services                        |
|---------|---------|---------------|-----------------------|---------------------------------|
| Mac 1   | Hardik  | 10.7.6.152    | (see networksetup)    | Primary DNS (dnsmasq :53)       |
| Mac 2   | Abuzar  | 10.7.31.75    | 10:9f:41:c6:18:10     | Primary nginx HTTPS Edge :8443  |
| Mac 3   | Kabir   | 10.7.11.100   | 10:9f:41:bb:f2:f8     | Backend A :3001, Standby Edge   |
| Mac 4   | Ayush   | 10.7.15.153   | 10:9f:41:c4:af:01     | Backend B :3002, Backup DNS     |

**Domain names (`.test` TLD — no public DNS pollution):**

| Domain                  | Resolves to   | Service              |
|-------------------------|---------------|----------------------|
| `app.Kuch_Nahi.test`    | 10.7.31.75    | nginx HTTPS Edge     |
| `api.Kuch_Nahi.test`    | 10.7.31.75    | nginx HTTPS Edge     |

---

## 3. OSI / TCP-IP Layer Mapping

| Layer         | OSI Layer | Protocol / Component          | In This Project                              |
|---------------|-----------|-------------------------------|----------------------------------------------|
| Application   | 7         | HTTP/HTTPS, REST API          | Python Flask backends, nginx proxy, curl     |
| Presentation  | 6         | TLS 1.2/1.3                   | Self-signed CA; nginx terminates TLS         |
| Session       | 5         | TCP sessions, TLS handshake   | nginx keepalive, TLS session resume          |
| Transport     | 4         | TCP                           | Port 8443 (HTTPS), 3001, 3002 (backends)    |
| Network       | 3         | IPv4                          | 10.7.0.0/16 private LAN, IP routing         |
| Data Link     | 2         | Ethernet/Wi-Fi (802.11)       | MAC addresses above, ARP                    |
| Physical      | 1         | Wi-Fi radio                   | University Wi-Fi / lab switch               |

---

## 4. Request Flow (normal path)

```
Client (any Mac)
    │
    │  1. DNS query: app.Kuch_Nahi.test ?
    ▼
dnsmasq @ 10.7.6.152:53
    │  returns 10.7.31.75
    │
    │  2. TCP + TLS to 10.7.31.75:8443
    ▼
nginx @ Mac 2 (Abuzar) — HTTPS edge
    │  terminates TLS (self-signed CA)
    │  round-robin upstream
    │  adds X-Backend: A|B header
    │
    ├──► 3a. HTTP to Mac 3 (Kabir) :3001  → Backend A
    └──► 3b. HTTP to Mac 4 (Ayush) :3002  → Backend B
```

**Cache hit path:**
```
Client → nginx → 304 Not Modified (from ETag / Cache-Control: max-age=60)
```

---

## 5. Cloud Equivalent Mapping

| This Project            | AWS Equivalent     | GCP Equivalent          | Purpose                      |
|-------------------------|--------------------|--------------------------|------------------------------|
| dnsmasq (Mac 1)         | Route 53 Private   | Cloud DNS Private Zone   | Private DNS resolution       |
| nginx (Mac 2)           | ALB / CloudFront   | Cloud Load Balancer      | TLS termination + LB         |
| Backend A (Mac 3 :3001) | EC2 / ECS Task     | Cloud Run instance       | App server instance A        |
| Backend B (Mac 4 :3002) | EC2 / ECS Task     | Cloud Run instance       | App server instance B        |
| pf firewall rules       | Security Groups    | VPC Firewall Rules       | Service isolation             |
| Backup DNS (Mac 4)      | Route 53 secondary | Cloud DNS failover       | DNS high availability        |
| Self-signed CA          | ACM Private CA     | Certificate Authority    | Internal TLS trust            |

---

## 6. High-Availability Architecture (Phase 2)

```
                   ┌────────────────────────────────────┐
                   │        DNS Layer                    │
                   │  Primary:  dnsmasq @ 10.7.6.152    │
                   │  Backup:   dnsmasq @ 10.7.15.153   │
                   └──────────────┬─────────────────────┘
                                  │
                   ┌──────────────▼─────────────────────┐
                   │        Edge Layer                   │
                   │  Primary:  nginx @ 10.7.31.75:8443  │
                   │  Standby:  nginx @ 10.7.11.100:8443 │
                   │  (DNS cutover via TTL=30s)          │
                   └──────────────┬─────────────────────┘
                                  │
              ┌───────────────────┴──────────────────┐
              │                                       │
   ┌──────────▼──────────┐             ┌─────────────▼─────────┐
   │  Backend A           │             │  Backend B             │
   │  Mac 3 :3001         │             │  Mac 4 :3002           │
   │  (Kabir)             │             │  (Ayush)               │
   └─────────────────────┘             └────────────────────────┘
```

**Failure modes handled:**
- Backend A down → nginx serves only Backend B (Extension D)
- Primary DNS down → Backup DNS on Mac 4 answers (Extension A)
- Primary edge down → DNS TTL expires (30s), cutover to standby (Extension B/E)
- Direct port access blocked by pf → only nginx can reach backends (Extension C)

---

## 7. TLS Certificate Chain

```
Root CA (self-signed)
  └── server.crt (signed by CA)
        SAN: DNS:app.Kuch_Nahi.test, DNS:api.Kuch_Nahi.test
        Issued by: Kabir
        Trusted by: all 4 Macs (ca.crt added to keychain / passed via --cacert)
```

**Files:**
- `configs/tls/server.cnf` — OpenSSL config with SAN
- `ca.crt`, `ca.key` — Root CA (kept on Mac 2)
- `server.crt`, `server.key` — Server cert/key (nginx on Mac 2)

---

*Document generated for Review 2 submission — Team Kuch Nahi, Nov 2026*

