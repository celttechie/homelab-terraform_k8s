#!/usr/bin/env python3
import http.server
import socket
import subprocess
import json
import os

PORT = 30080

class DashboardHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            hostname = socket.gethostname()
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            try:
                s.connect(('8.8.8.8', 80))
                primary_ip = s.getsockname()[0]
            except Exception:
                primary_ip = '127.0.0.1'
            finally:
                s.close()

            data = {
                "hostname": hostname,
                "ip": primary_ip,
                "uptime": subprocess.check_output(['uptime', '-p']).decode().strip()
            }
            self.wfile.write(json.dumps(data).encode())
            return

        hostname = socket.gethostname()
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.connect(('8.8.8.8', 80))
            primary_ip = s.getsockname()[0]
        except Exception:
            primary_ip = '127.0.0.1'
        finally:
            s.close()

        try:
            uptime_str = subprocess.check_output(['uptime', '-p']).decode('utf-8').strip()
        except Exception:
            uptime_str = "Up"

        try:
            ip_route_output = subprocess.check_output(['ip', '-4', 'addr', 'show']).decode('utf-8').strip()
        except Exception:
            ip_route_output = primary_ip

        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Homelab K8s Live Dynamic Dashboard</title>
  <style>
    :root {{
      --bg-primary: #0f172a;
      --bg-card: #1e293b;
      --text-primary: #f8fafc;
      --text-secondary: #94a3b8;
      --accent-blue: #38bdf8;
      --accent-green: #22c55e;
      --accent-purple: #a855f7;
      --border: #334155;
    }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--bg-primary);
      color: var(--text-primary);
      margin: 0;
      padding: 2rem;
    }}
    .header {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 2rem;
      padding-bottom: 1rem;
      border-bottom: 1px solid var(--border);
    }}
    .title-group h1 {{ margin: 0; font-size: 1.8rem; color: var(--accent-blue); }}
    .title-group p {{ margin: 0.25rem 0 0; color: var(--text-secondary); }}
    .status-badge {{
      background: rgba(34, 197, 94, 0.15);
      color: var(--accent-green);
      border: 1px solid var(--accent-green);
      padding: 0.5rem 1rem;
      border-radius: 9999px;
      font-weight: 600;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 1.5rem;
      margin-bottom: 2rem;
    }}
    .card {{
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 0.75rem;
      padding: 1.5rem;
    }}
    .card-header {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 1rem;
    }}
    .card-title {{ font-weight: 600; font-size: 1.1rem; color: var(--text-secondary); }}
    .card-value {{ font-size: 2rem; font-weight: 700; color: var(--accent-blue); }}
    pre {{
      background: #090d16;
      padding: 1rem;
      border-radius: 0.5rem;
      border: 1px solid var(--border);
      overflow-x: auto;
      color: var(--accent-green);
      font-family: monospace;
      font-size: 0.9rem;
    }}
  </style>
</head>
<body>
  <div class="header">
    <div class="title-group">
      <h1>⚡ Live Dynamic K8s Node Dashboard</h1>
      <p>Real-Time Dynamic Runtime Inspection — Stage 2 Worker Domain</p>
    </div>
    <div class="status-badge">● DYNAMICALLY PROBED LIVE</div>
  </div>

  <div class="grid">
    <div class="card">
      <div class="card-header">
        <span class="card-title">Real Runtime Node IP</span>
      </div>
      <div class="card-value" style="color: var(--accent-green);">{primary_ip}</div>
      <p style="color: var(--text-secondary); margin: 0.5rem 0 0;">Probed dynamically from live interface socket</p>
    </div>

    <div class="card">
      <div class="card-header">
        <span class="card-title">Serving Hostname</span>
      </div>
      <div class="card-value" style="color: var(--accent-purple);">{hostname}</div>
      <p style="color: var(--text-secondary); margin: 0.5rem 0 0;">Active worker node domain</p>
    </div>

    <div class="card">
      <div class="card-header">
        <span class="card-title">Node Uptime</span>
      </div>
      <div class="card-value" style="color: var(--accent-blue);">{uptime_str}</div>
      <p style="color: var(--text-secondary); margin: 0.5rem 0 0;">System uptime</p>
    </div>
  </div>

  <div class="card">
    <div class="card-header">
      <span class="card-title">Real-Time Interface Inspection (`ip -4 addr show`)</span>
    </div>
    <pre>{ip_route_output}</pre>
  </div>
</body>
</html>"""
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode('utf-8'))

if __name__ == '__main__':
    server = http.server.HTTPServer(('0.0.0.0', PORT), DashboardHandler)
    print(f"Starting Dynamic Dashboard on port {PORT}...")
    server.serve_forever()
