# ─── Stage 1: Builder ────────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --user -r requirements.txt

# ─── Stage 2: Test Runner ─────────────────────────────────────────────────────
FROM builder AS tester

WORKDIR /app
COPY app/ .
RUN python -m pytest tests/ -v --cov=src --cov-report=xml --cov-report=term-missing

# ─── Stage 3: Production Image ───────────────────────────────────────────────
FROM python:3.11-slim AS production

RUN groupadd -r appgroup && useradd -r -g appgroup appuser

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /root/.local /home/appuser/.local

COPY app/src/ ./src/

RUN chown -R appuser:appgroup /app

USER appuser

ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=5000

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", \
     "--threads", "2", "--timeout", "60", \
     "--access-logfile", "-", "--error-logfile", "-", \
     "src.app:app"]
