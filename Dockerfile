# --- Stage 1: frontend build ---
FROM node:20-slim AS frontend-build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY apps/notes/static_src ./apps/notes/static_src
RUN npm run build            # prebuild hook runs typecheck first; fails the build on a type error
 
# --- Stage 2: Python runtime ---
FROM python:3.12-slim AS runtime
WORKDIR /app
 
RUN groupadd -r appuser && useradd -r -g appuser appuser
 
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
 
COPY . .
COPY --from=frontend-build /app/static ./static
 
ENV DJANGO_SETTINGS_MODULE=notesy.settings \
    DJANGO_DEBUG=False
 
RUN python manage.py collectstatic --noinput
 
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
 
USER appuser
EXPOSE 8000
ENTRYPOINT ["/entrypoint.sh"]
CMD ["gunicorn", "notesy.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
