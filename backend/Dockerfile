FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
ARG INSTALL_DEV=false
WORKDIR /app

COPY pyproject.toml ./
RUN if [ "$INSTALL_DEV" = "true" ]; then pip install --no-cache-dir ".[dev]"; \
    else pip install --no-cache-dir .; fi

RUN useradd --system --create-home --uid 1000 app
COPY --chown=app:app . .
USER app

EXPOSE 8000
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]
