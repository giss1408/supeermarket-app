# Supermarket app

Monorepo. The Django + DRF + PostgreSQL backend lives in `backend/`.

## Backend quickstart

```bash
cp .env.example .env
docker compose up -d db mailpit
cd backend
python3.13 -m venv .venv && . .venv/bin/activate
pip install -e ".[dev]"
export DATABASE_URL=postgres://app:app@localhost:5434/app
python manage.py migrate
pytest
```

Or run everything in containers: `docker compose up -d db && docker compose run --rm web pytest`.

Health check: `GET /healthz` returns `{"status": "ok"}`. Mailpit UI: http://localhost:8025.
