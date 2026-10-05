#!/bin/bash
# quick-test.sh — Run all key tests for the CN Project
# Computer Networks Project — Team Kuch_Nahi
#
# Run this from Mac 3 or Mac 4 to verify the full stack is working.
# Prerequisites: all 4 Macs running, DNS and nginx up.
#
# Usage: bash scripts/quick-test.sh

set -e

MAC1="10.7.7.36"
MAC2="10.7.19.243"
MAC3="10.7.21.89"
MAC4="10.7.24.95"
DOMAIN="app.Kuch_Nahi.test"
PORT="8443"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  CN Project — Team Kuch_Nahi — Quick Test Suite"
echo "═══════════════════════════════════════════════════════"
echo ""

# ── A5: Ping test ────────────────────────────────────────────
echo "▶ [A5] Ping all machine pairs..."
for TARGET in $MAC2 $MAC3 $MAC4; do
    ping -c 4 "$TARGET" | tail -2
done
echo ""

# ── A3: DNS resolution ───────────────────────────────────────
echo "▶ [A3] DNS resolution via Mac 1 (private DNS)..."
dig "$DOMAIN"
echo ""

# ── A4: Prove domain is private ──────────────────────────────
echo "▶ [A4] Prove domain is NOT in public DNS (expect NXDOMAIN)..."
dig @8.8.8.8 "$DOMAIN" | grep -E "status:|ANSWER SECTION|NXDOMAIN"
echo ""

# ── B1: HTTPS connection ─────────────────────────────────────
echo "▶ [B1] HTTPS test (NO -k flag)..."
curl -v "https://${DOMAIN}:${PORT}/" 2>&1 | grep -E "TLSv|subject:|subjectAltName|HTTP/"
echo ""

# ── B2: Load balancing (6 requests) ──────────────────────────
echo "▶ [B2] Load balancing — 6 requests (should alternate A and B)..."
for i in {1..6}; do
    echo -n "  Request $i: "
    curl -s -D - "https://${DOMAIN}:${PORT}/api/status" -o /dev/null | grep -i "^X-Backend:"
done
echo ""

# ── D1: Caching headers ──────────────────────────────────────
echo "▶ [D1] HTTP caching headers..."
curl -sI "https://${DOMAIN}:${PORT}/api/status" | grep -iE "Cache-Control|ETag|Date|X-Backend"
echo ""

echo "═══════════════════════════════════════════════════════"
echo "  All tests complete."
echo "═══════════════════════════════════════════════════════"
echo ""
