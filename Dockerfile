# ========================
# 🛠️ Build Stage - Frontend
# ========================
FROM node:18-alpine as frontend-builder

WORKDIR /app/web
COPY web/package*.json ./
RUN npm ci --silent
COPY web/ .
RUN npm run build

# ========================
# 🐍 Base Python Environment
# ========================
FROM python:3.11-slim as base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# ========================
# 📦 Dependency Installation
# ========================
FROM base as python-builder

WORKDIR /install

COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

# ========================
# 🚀 Final Production Image
# ========================
FROM base

# Copy Python dependencies
COPY --from=python-builder /install /usr/local

# Copy application code
COPY ai/ ai/
COPY config/ config/
COPY storage/ storage/
COPY app/ app/

# Copy built frontend assets
COPY --from=frontend-builder /app/web/assets/dist web/assets/dist

# Create required directories
RUN mkdir -p \
    storage/logs \
    storage/backup \
    ai/finetune/trained_models \
    && chmod -R 755 storage/

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Expose application port
EXPOSE 8000

# ========================
# 🏃 Runtime Configuration
# ========================
CMD ["gunicorn", "app.main:app", \
    "--bind", "0.0.0.0:8000", \
    "--workers", "4", \
    "--worker-class", "uvicorn.workers.UvicornWorker"]
