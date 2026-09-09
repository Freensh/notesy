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
npm run build                        # compiles the TS bundle to static/js/
python manage.py migrate
python manage.py seed                # creates a demo user (demo/demo) + sample notes
python manage.py runserver
```

Visit http://localhost:8000 and log in as `demo` / `demo`.

See `DEPLOYMENT_GUIDE.md` for the task at hand.
