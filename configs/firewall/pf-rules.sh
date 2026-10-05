#!/bin/bash
# pf-rules.sh — Phase 2 Service Isolation Firewall Rules
# Computer Networks Project — Team Kuch_Nahi
# Machine: Mac 3 (Kabir Sharma) and Mac 4 (Ayush Tiwari)
#
# Goal:
#   ALLOW  Mac 2 (10.7.19.243) → Mac 3:3001  (nginx → Backend A)
#   ALLOW  Mac 2 (10.7.19.243) → Mac 4:3002  (nginx → Backend B)
#   BLOCK  all other direct access to port 3001 / 3002
#
# This proves that clients CANNOT bypass nginx and hit backends directly.
#
# ─── USAGE ───────────────────────────────────────────────────
#
# On Mac 3 (to protect port 3001):
#   1. sudo cp /etc/pf.conf /etc/pf.conf.cnproject-backup   ← BACKUP FIRST
#   2. sudo cp pf-rules-mac3.conf /etc/pf.anchors/cnproject
#   3. Edit /etc/pf.conf and add the anchor (see ANCHOR ADDITION below)
#   4. sudo pfctl -nf /etc/pf.conf    ← dry run test
#   5. sudo pfctl -f /etc/pf.conf     ← apply
#   6. sudo pfctl -e                  ← enable pf
#
# To ROLLBACK (run this after demonstration):
#   sudo pfctl -d
#   sudo cp /etc/pf.conf.cnproject-backup /etc/pf.conf
#
# ─────────────────────────────────────────────────────────────

# ─── pf-rules-mac3.conf (protect Backend A port 3001) ────────
# Add to /etc/pf.anchors/cnproject on Mac 3:
#
# pass in quick on en0 inet proto tcp \
#   from 10.7.19.243 to any port 3001 \
#   flags S/SA keep state
#
# block in quick on en0 inet proto tcp \
#   from any to any port 3001
#
# ─── pf-rules-mac4.conf (protect Backend B port 3002) ────────
# Add to /etc/pf.anchors/cnproject on Mac 4:
#
# pass in quick on en0 inet proto tcp \
#   from 10.7.19.243 to any port 3002 \
#   flags S/SA keep state
#
# block in quick on en0 inet proto tcp \
#   from any to any port 3002
#
# ─── ANCHOR ADDITION (add to /etc/pf.conf on each Mac) ───────
# anchor "cnproject"
# load anchor "cnproject" from "/etc/pf.anchors/cnproject"
#
# ─── TEST SERVICE ISOLATION ──────────────────────────────────
# From Mac 2 (nginx) — should SUCCEED:
#   curl http://10.7.21.89:3001/api/status    → 200 OK
#   curl http://10.7.24.95:3002/api/status    → 200 OK
#
# From Mac 4 (client) — should FAIL/timeout:
#   curl --connect-timeout 5 http://10.7.21.89:3001/api/status  → Connection refused
#
# From Mac 3 (client) — should FAIL/timeout:
#   curl --connect-timeout 5 http://10.7.24.95:3002/api/status  → Connection refused
