[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/docsgpt?utm_medium=integration&utm_source=button&utm_campaign=docsgpt)

# DocsGPT on Railway

A Railway template for [DocsGPT](https://github.com/arc53/DocsGPT) (MIT), the open-source AI assistant that answers from your own documents: upload files or crawl sites, chat with cited answers, build agents with tools and schedules, and call them through a chat widget or an OpenAI-compatible API.

**Version:** DocsGPT **1.1.0**, from the official `arc53/docsgpt` image, pinned by version and digest in the [`Dockerfile`](Dockerfile).

## What it deploys

| Service | Source | Public | Storage |
|---|---|---|---|
| DocsGPT | this repo (`Dockerfile`: `FROM arc53/docsgpt:1.1.0@sha256:761de60b…`) | yes, health check `/api/health` | volume at `/data` (uploaded files, indexes) |
| Postgres | Railway's Postgres (pgvector included) | no (private network) | volume at `/var/lib/postgresql/data` (users, chats, agents, vectors) |
| Redis | Railway's Redis | no (private network) | volume at `/data` (task queue, schedules) |

What the small wrapper ([`start.sh`](start.sh)) adds to the official image:

- **API and worker in one service.** It runs the API (which also serves the web UI) on Railway's `PORT` and the Celery worker next to it, as upstream's native install does. Both use the same `/data` volume, and the worker hands finished indexes to the API over localhost.
- **Sign-in on.** Upstream ships with no sign-in, which on a public URL means anyone can use your instance. This template sets `AUTH_TYPE=simple_jwt`: the API prints one access token in its deploy logs, and the web UI asks for it.
- **Safe defaults:** all secrets are generated per deployment, `DEPLOYMENT_TYPE=production`, vectors in Postgres (`VECTOR_STORE=pgvector`), files on the volume, and the hosted DocsGPT model (`LLM_PROVIDER=docsgpt`), so it works with no API key. The embedding model is baked into the image.
- **Start order.** The API creates and migrates the database on first start; the worker starts once the API answers.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `PORT` | `7091` | |
| `JWT_SECRET_KEY` | `${{secret(64)}}` | Signs the access token. Change it to revoke the token. |
| `INTERNAL_KEY` | `${{secret(48)}}` | Shared by the API and the worker. |
| `ENCRYPTION_SECRET_KEY` | `${{secret(64)}}` | Seals stored credentials (tools, connectors). Don't change it later. |
| `API_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public address, used in links DocsGPT hands out. Update it for a custom domain. |
| `POSTGRES_URI` | `${{Postgres.DATABASE_URL}}` | Private network. |
| `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND`, `CACHE_REDIS_URL` | `${{Redis.REDIS_URL}}/0`, `/1`, `/2` | Private network. |

Optional, add them to the DocsGPT service:

- `LLM_PROVIDER` (`openai`, `anthropic`, `google`, `groq`, `openrouter`, `novita`) and `API_KEY` to use your own model provider; `LLM_NAME` to pick a model. For an OpenAI-compatible server (Ollama, vLLM), `LLM_PROVIDER=openai`, `OPENAI_BASE_URL` and `LLM_NAME`.
- `AUTH_TYPE=oidc` with `OIDC_ISSUER`, `OIDC_CLIENT_ID` and `OIDC_FRONTEND_URL` for one account per person, admins and quotas. See upstream's [SSO with OIDC](https://docs.docsgpt.cloud/Deploying/OIDC-SSO).
- `VERSION_CHECK=false` turns off the worker's version check to `gptcloud.arc53.com`.
- `WORKER_CONCURRENCY` (default `2`): Celery processes. More ingests faster but needs more RAM.
- Any other setting from upstream's [settings reference](https://docs.docsgpt.cloud/Deploying/Settings-Reference).

## After deploying

1. Wait until all three services are green (the first start runs the database migrations).
2. Open the DocsGPT service's latest deploy logs and find `Generated Simple JWT Token:`. Copy the token after it.
3. Open the DocsGPT domain and paste the token when the page asks for it.
4. Add a source (upload a file or add a website), wait until it's ready, then ask a question.

The token is one shared credential: everyone who has it uses the same account. Keep it private, and set a new `JWT_SECRET_KEY` to revoke it.

**Memory:** ingesting documents runs the embedding model on the CPU and needs about 1.5 GB of RAM, so use the Hobby plan or higher.

## Updates

Railway tells everyone who deployed this template when `main` of this repo changes, and you choose when to apply the update. Each change is listed in [CHANGELOG.md](CHANGELOG.md), breaking changes first. DocsGPT runs its database migrations on start. Back up Postgres before a major upgrade and read the [release notes](https://github.com/arc53/DocsGPT/releases).

Maintainers: bump the `FROM` pin (version and digest together) and add a `CHANGELOG.md` entry.

## Licence

This wrapper is MIT-licensed. DocsGPT is MIT-licensed by Arc53.
