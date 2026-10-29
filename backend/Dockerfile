# syntax=docker/dockerfile:1

# ---- builder: compile wheels once so the final image carries no build cache ----
FROM python:3.13-slim AS builder
ARG INSTALL_DEV=false
WORKDIR /build
COPY pyproject.toml ./
RUN if [ "$INSTALL_DEV" = "true" ]; then pip wheel --wheel-dir /wheels ".[dev]"; \
    else pip wheel --wheel-dir /wheels .; fi

# ---- final image ----
FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
# Production by default. docker-compose.yml (dev) overrides this with config.settings.dev.
ENV DJANGO_SETTINGS_MODULE=config.settings.prod
ARG INSTALL_DEV=false
WORKDIR /app

RUN --mount=type=bind,from=builder,source=/wheels,target=/wheels \
    if [ "$INSTALL_DEV" = "true" ]; then \
      pip install --no-cache-dir --no-index --find-links=/wheels "supermarket-backend[dev]"; \
    else pip install --no-cache-dir --no-index --find-links=/wheels supermarket-backend; fi

RUN useradd --system --create-home --uid 1000 app
COPY --chown=app:app . .

# Collect admin static files into the image. The key and database URL exist only for this RUN
# (they satisfy the production settings guards) and are never stored in the image environment.
RUN SECRET_KEY=build-time-only-not-a-secret-0123456789abcdef \
    DATABASE_URL=postgres://build:build@localhost:5432/build \
    ALLOWED_HOSTS=localhost \
    python manage.py collectstatic --noinput

# Local-disk media directory (used only when S3 is not configured). Created here, owned by
# the app user, so a named volume mounted on it inherits the right ownership.
RUN mkdir -p /app/media && chown app:app /app/media

USER app
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD ["python", "healthcheck.py"]

# `sh -c` so ${WEB_CONCURRENCY} expands; `exec` keeps gunicorn as PID 1 for signal handling.
CMD ["sh", "-c", "exec gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers ${WEB_CONCURRENCY:-3} --timeout 30 --access-logfile - --error-logfile - --worker-tmp-dir /dev/shm"]
