"""
Backend Server A — Port 3001
Computer Networks Project — Team Kuch_Nahi
Machine: Mac 3 (Kabir Sharma)

This server runs on Mac 3 (10.7.21.89).
Nginx on Mac 2 (10.7.19.243) load-balances between:
  - Backend A (this file) → Mac 3 :3001
  - Backend B             → Mac 4 :3002

The X-Backend: A header proves which backend served each request.
"""

from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from email.utils import formatdate

HOST = "0.0.0.0"
PORT = 3001
BACKEND = "A"
ETAG = '"backend-a-v1"'


class Handler(BaseHTTPRequestHandler):

    def send_common_headers(self):
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "max-age=60")
        self.send_header("ETag", ETAG)
        self.send_header("X-Backend", BACKEND)
        self.send_header("Date", formatdate(usegmt=True))

    def do_GET(self):
        if self.path == "/api/status":
            # Support conditional GET (ETag / 304 Not Modified)
            if self.headers.get("If-None-Match") == ETAG:
                self.send_response(304)
                self.send_common_headers()
                self.end_headers()
                return

            body = {
                "status": "ok",
                "backend": BACKEND,
                "server": "Mac 3 — Kabir Sharma",
                "ip": "10.7.21.89",
                "port": PORT
            }
            data = json.dumps(body, indent=2).encode()

            self.send_response(200)
            self.send_common_headers()
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        else:
            body = {
                "message": "Backend A — Computer Networks Project",
                "backend": BACKEND,
                "team": "Kuch_Nahi"
            }
            data = json.dumps(body, indent=2).encode()

            self.send_response(200)
            self.send_common_headers()
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    def log_message(self, format, *args):
        print(f"[Backend {BACKEND}] {self.address_string()} — {format % args}")


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), Handler)
    print(f"\n🚀 Backend Server A running on http://{HOST}:{PORT}")
    print(f"   X-Backend: {BACKEND}")
    print(f"   Machine: Mac 3 — Kabir Sharma (10.7.21.89)")
    print(f"   Press Ctrl+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[Backend A] Stopped.")
        server.server_close()
