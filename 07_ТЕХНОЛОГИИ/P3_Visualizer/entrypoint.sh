#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════╗"
echo "║  DYNAMIS v3.0 — P³ Лаборатория                     ║"
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
