# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

A personal template repository for containerized microservice deployment configurations. It covers Spring Boot (Java/Kotlin) backends deployed via Docker Compose (local/staging) and Kubernetes (production), with CI/CD via CircleCI and GitHub Actions.

## Utility Scripts

### `spring_boot_init.sh`
Interactive script for scaffolding Maven multi-module Spring Boot projects. Run directly:
```bash
./spring_boot_init.sh
```
Creates parent `pom.xml`, module directories with Java/Kotlin source trees, `application.yml`, and Spring Boot application classes. Targets Spring Boot 3.2.2 / Kotlin 1.9.23.

### `kill-memory-hogs.sh`
Interactive macOS process manager — lists top 15 memory consumers, supports SIGTERM/SIGKILL with confirmation:
```bash
./kill-memory-hogs.sh
```

### `storage_cleaner.sh`
macOS disk-space recovery script — scans caches, build artifacts (Xcode, Android, npm, Gradle), and logs:
```bash
./storage_cleaner.sh
```

### `Gitlab/git-push.sh`
Git workflow helper — checks branch sync status, validates uncommitted changes, enforces `master` for deploys, prompts for commit message:
```bash
./Gitlab/git-push.sh
```

## Docker Compose Services

All compose files live in `Docker/`. The shared `.env` file controls credentials and ports — **all `REQUIRED` fields in `.env` must be filled before running any service**.

| File | Service | Default Port |
|------|---------|-------------|
| `docker-compose-postgres.yaml` | PostgreSQL 14.1 | 5433 |
| `docker-compose-mongodb.yaml` | MongoDB 6 | 27017 |
| `docker-compose-redis.yaml` | Redis Stack + Web UI | 6379 / 8004 |
| `docker-compose-kafka.yaml` | Kafka (3 brokers, SASL/SCRAM) + UI | 9092-9094 / 8080 |
| `docker-compose-hashicorp-vault.yaml` | HashiCorp Vault | 8200 |
| `docker-compose-minio.yaml` | MinIO S3 | 9000 |
| `docker-compose-pgadmin.yaml` | PgAdmin | 7006 |
| `docker-compose-services.yaml` | PostgreSQL + Superset | 8088 |
| `keycloak/docker-compose.yaml` | Keycloak 23.0.7 + PostgreSQL | 8999 |

Start any service from the `Docker/` directory:
```bash
cd Docker && docker compose -f docker-compose-<service>.yaml up -d
```

After starting Vault, initialize it (reads secrets from env vars `JWT_SECRET`, `DB_USERNAME`, `DB_PASSWORD`):
```bash
cd Docker && bash vault/init.sh
```
The init script writes unseal keys to `/vault/vault-init.json` — move that file to secure offline storage immediately and delete it from the server.

### Keycloak production mode
Keycloak runs in `start` (production) mode. Required env vars in `Docker/keycloak/.env` (or the parent `.env`): `KC_DB_PASSWORD`, `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`, `KC_HOSTNAME`.

## Kubernetes

Manifests are in `kubernetes/`. Production target: `botswanaemrdev.intellisoftkenya.com` with NGINX ingress.

- `backend-service.yaml` — Deployment (3 replicas) + NodePort Service for the auth service
- `ingress.yaml` — NGINX Ingress with TLS, proxying `/auths` to authservice
- `ssl.yaml` — TLS Secret (base64-encoded cert/key; replace values for new environments)

Apply all manifests:
```bash
kubectl apply -f kubernetes/
```

## CI/CD Pipelines

| File | Platform | Image pushed |
|------|----------|-------------|
| `Pipelines/circle-ci.yaml` | CircleCI | `dnjau/botswana_emr_auth_image:v3` |
| `Pipelines/github-workflow.yaml` | GitHub Actions | `nimonatural/sms_revampmanager_image:1` |
| `Pipelines/github.yml` | GitHub Actions (multi-instance) | PSS international + national images |

All pipelines build with Maven, push to Docker Hub, then SSH-deploy to a remote K8s node. Credentials are stored as CI secrets (`DOCKER_HUB_USERNAME`, `DOCKER_HUB_PASSWORD`, `SSH_HOST`, etc.).

## Architecture Notes

- **Backend target**: Spring Boot 3.2.2 (Java/Kotlin), Maven multi-module
- **Auth**: Keycloak 23.0.7 handles SSO; generated projects include Keycloak adapter config in `application.yml`
- **Secrets at runtime**: HashiCorp Vault (KV v2) is the intended secrets store for production services
- **Multi-instance deployments** (`github.yml`): builds separate images for `international` and `national` instances of the same service, deploying to separate remote hosts via SSH
