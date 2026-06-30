# Backend container for Koyeb / Fly.io / any Docker host.
# Build context = repo root, because app/seed.py reads CSVs from ../../database.
#
# Local test:
#   docker build -t agripulse-backend .
#   docker run -p 8000:8000 -e DATABASE_URL=postgresql://... agripulse-backend
FROM python:3.11-slim

WORKDIR /app

# Install deps first for better layer caching.
COPY backend/requirements.txt backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

# App code + the seed data folder (seed.py resolves ../../database/seed/data).
COPY backend/ backend/
COPY database/ database/

WORKDIR /app/backend
ENV PYTHONUNBUFFERED=1

# Seed is idempotent (skips existing rows) so the demo accounts exist on first
# boot. $PORT is provided by the host (Koyeb/Fly); default 8000 for local runs.
CMD ["sh", "-c", "python -m app.seed && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
