#!/bin/sh
set -e
 
if [ -n "$POSTGRES_HOST" ]; then
  echo "Waiting for Postgres at $POSTGRES_HOST:${POSTGRES_PORT:-5432}..."
  until python -c "
import socket, sys
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(2)
try:
    s.connect(('$POSTGRES_HOST', int('${POSTGRES_PORT:-5432}')))
    sys.exit(0)
except Exception:
    sys.exit(1)
"; do
    echo "Postgres not ready yet, retrying in 2s..."
    sleep 2
  done
  echo "Postgres is up."
fi
 
python manage.py migrate --noinput
python manage.py seed || true   # idempotent demo/demo seed, optional in prod
 
exec "$@"
