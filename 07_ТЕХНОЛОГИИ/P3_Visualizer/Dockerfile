# ═══════════════════════════════════════════════════════════════
# DYNAMIS v2.1 — P³ Projective Geography Platform
# Docker image: docker run -p 8080:80 dynamis
# ═══════════════════════════════════════════════════════════════

FROM python:3.11-slim AS base

LABEL maintainer="Eteryya Project"
LABEL description="DYNAMIS — P³ Projective Geography & World Design Platform"
LABEL version="2.1"

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    && rm -rf /var/lib/apt/lists/*

# Python deps
RUN pip install --no-cache-dir \
    numpy \
    sympy \
    clifford

# ═══════════════════════════════════════════════════════════════
# Build stage
# ═══════════════════════════════════════════════════════════════
FROM base AS builder

WORKDIR /build

# Copy kernel + extensions + Ouroboros
COPY kernel/ /build/kernel/
COPY extensions/ /build/extensions/

# Test kernel
RUN python -c "import sys; sys.path.insert(0,'/build/kernel'); from p3_kernel import HomVec4; print('P³ Kernel OK')"

# ═══════════════════════════════════════════════════════════════
# Runtime stage
# ═══════════════════════════════════════════════════════════════
FROM base AS runtime

WORKDIR /dynamis

# Copy Python backend
COPY --from=builder /build/kernel/ /dynamis/kernel/
COPY --from=builder /build/extensions/ /dynamis/kernel/extensions/

# Copy frontend
COPY index.html /dynamis/web/index.html
COPY extensions.js /dynamis/web/extensions.js

# Nginx config
RUN cat > /etc/nginx/sites-available/dynamis << 'EOF'
server {
    listen 80;
    server_name _;
    
    root /dynamis/web;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
    }
}

EOF
RUN ln -sf /etc/nginx/sites-available/dynamis /etc/nginx/sites-enabled/dynamis
RUN rm -f /etc/nginx/sites-enabled/default

# API server (simple Python HTTP for P³ computations)
RUN cat > /dynamis/api_server.py << 'PYEOF'
#!/usr/bin/env python3
"""Simple API server for DYNAMIS P³ computations."""
import json
import sys
import os
from http.server import HTTPServer, BaseHTTPRequestHandler

sys.path.insert(0, '/dynamis/kernel')
from p3_kernel import HomVec4, fs_distance, w_from_distance, K_ANISO

class DynamisAPI(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/health':
            self._json(200, {'status': 'ok', 'version': '2.1'})
        elif self.path == '/api/constants':
            self._json(200, {
                'R_eteria_km': 5838.4,
                'R_earth_km': 6378.0,
                'K_aniso': float(K_ANISO),
                'resonance_hz': 18.7,
            })
        elif self.path.startswith('/api/fs_distance'):
            # ?x1=...&y1=...&z1=...&w1=...&x2=...&...
            params = self._parse_params()
            p1 = HomVec4(params['x1'], params['y1'], params['z1'], params['w1']).normalize()
            p2 = HomVec4(params['x2'], params['y2'], params['z2'], params['w2']).normalize()
            d = fs_distance(p1, p2)
            self._json(200, {'d_fs': d, 'd_fs_deg': d * 180 / 3.141592653589793})
        else:
            self._json(404, {'error': 'not found'})
    
    def _parse_params(self):
        from urllib.parse import parse_qs
        qs = parse_qs(self.path.split('?')[1] if '?' in self.path else '')
        return {k: float(v[0]) for k, v in qs.items()}
    
    def _json(self, code, data):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

if __name__ == '__main__':
    print("DYNAMIS API server on :8000")
    HTTPServer(('0.0.0.0', 8000), DynamisAPI).serve_forever()
PYEOF

# Entrypoint
RUN cat > /dynamis/entrypoint.sh << 'SHEOF'
#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════╗"
echo "║  DYNAMIS v2.1 — P³ Projective Geography Platform  ║"
echo "║  http://localhost:8080                            ║"
echo "╚══════════════════════════════════════════════════╝"

# Start API server in background
python /dynamis/api_server.py &
API_PID=$!

# Start nginx
nginx -g 'daemon off;' &
NGINX_PID=$!

# Wait
wait $API_PID $NGINX_PID
SHEOF
RUN chmod +x /dynamis/entrypoint.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost/api/health || exit 1

ENTRYPOINT ["/dynamis/entrypoint.sh"]
