# Notesy

A small Django + HTMX notes app.

## What it does

- Log in (session auth)
- List, create, edit, delete personal notes (HTMX-driven, no full page reloads)
- "Summarize" a note (calls out to an LLM-shaped service — currently stubbed with a simulated delay)

## Run it locally

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
npm install
cp .env.example .env                 # optional — see Environment variables below
npm run build                        # compiles the TS bundle to static/js/
python manage.py migrate
python manage.py seed                # creates a demo user (demo/demo) + sample notes
python manage.py runserver
```

Visit http://localhost:8000 and log in as `demo` / `demo`.

Copying `.env.example` to `.env` is optional for local dev — with no `.env` and no environment
variables set, the app falls back to SQLite and its other built-in defaults with zero setup.
Real environment variables (exported in your shell, or set by Docker/ECS/Kubernetes later)
always take precedence over values in `.env` — `.env` only fills in what isn't already set
elsewhere.

## Environment variables

| Variable | Controls | If unset |
|---|---|---|
| `DJANGO_SECRET_KEY` | Django's `SECRET_KEY` | Falls back to a hardcoded dev key. Fine for local dev, must be overridden anywhere else. |
| `DJANGO_DEBUG` | Django's `DEBUG` flag | Defaults to `True`. |
| `DJANGO_ALLOWED_HOSTS` | Django's `ALLOWED_HOSTS` (comma-separated, e.g. `example.com,www.example.com`) | Defaults to `["*"]`. |
| `POSTGRES_HOST` | Switches the database from SQLite to Postgres | If unset, the app falls back to a local SQLite file with no setup required. Sessions also fall back to file-based storage in this case. |
| `POSTGRES_DB` | Postgres database name | Only read when `POSTGRES_HOST` is set. |
| `POSTGRES_USER` | Postgres user | Only read when `POSTGRES_HOST` is set. |
| `POSTGRES_PASSWORD` | Postgres password | Only read when `POSTGRES_HOST` is set. |
| `POSTGRES_PORT` | Postgres port | Defaults to `5432` when `POSTGRES_HOST` is set. |
| `SUMMARIZER_API_KEY` | Currently unused | The "Summarize" feature is a local stub (see above) and doesn't call any external service yet — this is scaffolding for a future integration. |
| `SUMMARIZER_URL` | Currently unused | Same as above — no code reads this yet. |

## Running tests

Static file references (`{% static %}`) are validated against a manifest, so the frontend
bundle and `collectstatic` need to have been run at least once before `pytest` will pass:

```bash
npm run build
python manage.py collectstatic --noinput
pytest
```

## Health check

`/healthz/` runs a live `SELECT 1` against the database and returns 200 (JSON) if it succeeds,
503 (JSON, with error detail) if it doesn't — useful for wiring up monitoring or container
health checks later.

See `DEPLOYMENT_GUIDE.md` for the task at hand.
