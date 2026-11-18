# Changelog

Each entry lists breaking changes first. Railway shows deployers an update when `main` changes.

## 1.1.0 (2026-11-18)

- First release of this template: DocsGPT 1.1.0 (`arc53/docsgpt:1.1.0@sha256:761de60b3d1a683c9a2537d3b194b6858b6726934fd7f80f95b99aa87f466fbb`) with Railway's Postgres (pgvector) and Redis.
- Wrapper: runs the API and the Celery worker in one service on Railway's `PORT`, keeps runtime data on the `/data` volume, turns on `simple_jwt` sign-in, and starts the worker after the API's first migration.
