# ═══════════════════════════════════════════════════════════════
# DYNAMIS v3.0 — P³ Лаборатория
# Docker image: docker run -p 8080:80 dynamis
# ═══════════════════════════════════════════════════════════════

FROM python:3.11-slim AS base

LABEL maintainer="Eteryya Project"
LABEL description="DYNAMIS — P³ Лаборатория"
LABEL version="3.0"

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    curl \
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

# Test kernel
RUN python -c "import sys; sys.path.insert(0,'/build/kernel'); from p3_kernel import HomVec4; print('P³ Kernel OK')"

# ═══════════════════════════════════════════════════════════════
# Runtime stage
# ═══════════════════════════════════════════════════════════════
FROM base AS runtime

WORKDIR /dynamis

# Copy Python backend
COPY --from=builder /build/kernel/ /dynamis/kernel/

# Copy frontend
COPY index.html /dynamis/web/index.html
COPY extensions.js /dynamis/web/extensions.js

# Nginx config
COPY nginx.conf /etc/nginx/sites-available/dynamis
RUN ln -sf /etc/nginx/sites-available/dynamis /etc/nginx/sites-enabled/dynamis
RUN rm -f /etc/nginx/sites-enabled/default

# API server (simple Python HTTP for P³ computations)
COPY api_server.py /dynamis/api_server.py

# Entrypoint
COPY entrypoint.sh /dynamis/entrypoint.sh
RUN chmod +x /dynamis/entrypoint.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost/api/health || exit 1

ENTRYPOINT ["/dynamis/entrypoint.sh"]
