#!/bin/bash
# Runs the DocsGPT API (web UI included) and its Celery worker in one Railway
# service, the way upstream's native install does, so both share the /data
# volume and the worker hands finished indexes to the API over localhost.
set -uo pipefail

export PORT="${PORT:-7091}"

# Safe defaults for a public Railway domain. Every one can be overridden with a
# service variable of the same name.
export AUTH_TYPE="${AUTH_TYPE:-simple_jwt}"            # never run a public URL without auth
export DEPLOYMENT_TYPE="${DEPLOYMENT_TYPE:-production}" # a missing JWT_SECRET_KEY is fatal
export LLM_PROVIDER="${LLM_PROVIDER:-docsgpt}"          # hosted DocsGPT model, no key needed
export VECTOR_STORE="${VECTOR_STORE:-pgvector}"         # vectors in Postgres
export STORAGE_TYPE="${STORAGE_TYPE:-local}"            # files on the /data volume
export EMBEDDINGS_NAME="${EMBEDDINGS_NAME:-ibm-granite/granite-embedding-311m-multilingual-r2}"
export WORKER_API_URL="${WORKER_API_URL:-http://127.0.0.1:${PORT}}"
export PYTHONUNBUFFERED=1

for key in JWT_SECRET_KEY INTERNAL_KEY ENCRYPTION_SECRET_KEY POSTGRES_URI CELERY_BROKER_URL; do
  if [ -z "${!key:-}" ]; then
    echo "docsgpt-railway: $key is not set. Redeploy from the template or set it on this service." >&2
    exit 1
  fi
done

mkdir -p /data/inputs /data/indexes /data/vectors
cd /data

gunicorn -w 1 -k docsgpt.gunicorn_worker.BoundedDrainUvicornWorker \
  --bind "[::]:${PORT}" --timeout 180 --graceful-timeout 120 --keep-alive 5 \
  --worker-tmp-dir /dev/shm --max-requests 5000 --max-requests-jitter 500 \
  --config /app/docsgpt/gunicorn_conf.py docsgpt.asgi:asgi_app &
api=$!

# The API creates and migrates the database on its first start; start the
# worker once it answers, so the two never race on the migrations.
for _ in $(seq 1 240); do
  kill -0 "$api" 2>/dev/null || break
  python -c "import urllib.request,sys; urllib.request.urlopen('http://127.0.0.1:${PORT}/api/health', timeout=2)" 2>/dev/null && break
  sleep 1
done

celery -A docsgpt.app.celery worker -l INFO -B -c "${WORKER_CONCURRENCY:-2}" \
  -Q docsgpt,parsing,embeddings,ingest,analytics &
worker=$!

stop() { kill -TERM "$api" "$worker" 2>/dev/null; wait; exit 0; }
trap stop TERM INT

# If either process exits, stop the other and exit, so Railway restarts the service.
wait -n "$api" "$worker"
code=$?
echo "docsgpt-railway: a process exited with code $code, stopping" >&2
kill -TERM "$api" "$worker" 2>/dev/null
wait
exit "${code:-1}"
