# Database Stack — readme-database.md

Enterprise-ready PostgreSQL stack using Docker Compose. Covers setup, connection pooling, Redis, backups, monitoring, and restore procedures.

---

## Architecture

```
Application
    │
    │  SCRAM-SHA-256 auth
    ▼
┌─────────────────────┐
│  PgBouncer :6432    │  ← All app connections enter here
│  (transaction pool) │
└────────┬────────────┘
         │ pool of ≤100 server connections
         │ SCRAM-SHA-256
         ▼
┌─────────────────────┐       ┌───────────────────┐
│  PostgreSQL :5432   │       │   Redis :6379     │
│  (127.0.0.1 only)  │       │   (password auth)  │
└─────────────────────┘       └───────────────────┘
         │
         │ pg_dump (cron)
         ▼
┌─────────────────────┐
│  postgres-backup    │──→ Docker/backups/ on host
└─────────────────────┘
```

**Why PgBouncer?**
Each open PostgreSQL connection consumes ~5–10 MB of RAM and a backend process. Without pooling, a service with 50 instances × 10 connection threads = 500 idle Postgres connections. PgBouncer multiplexes all of those onto a small, tunable pool of real server connections (default: 25 per database/user pair).

**Pool mode — `transaction`**
A server connection is held only for the duration of a transaction, then returned to the pool. This gives the best density. If your app uses session-level features (`LISTEN/NOTIFY`, `SET LOCAL`, advisory locks, non-protocol-level prepared statements), switch to `session` mode in `pgbouncer.ini`.

---

## File Structure

```
Docker/
├── docker-compose-postgres.yaml   # Main compose file
├── .env                           # Secrets and config (fill before starting)
├── backups/                       # pg_dump output (bind-mounted from host)
│   ├── .gitkeep
│   └── .gitignore                 # Excludes *.dump / *.sql from git
└── postgres/
    ├── postgresql.conf            # PostgreSQL server config (tuning + logging)
    ├── pg_hba.conf                # Client auth rules (SCRAM on all network connections)
    ├── init.sh                    # First-boot: creates pgbouncer role + auth function
    ├── pgbouncer.ini              # PgBouncer config (pool sizing, timeouts, TLS stubs)
    ├── generate_userlist.sh       # PgBouncer entrypoint — writes userlist.txt at startup
    ├── backup.sh                  # pg_dump script with retry and retention
    └── backup-entrypoint.sh       # Configures crond schedule and starts it
```

---

## Prerequisites

- Docker Engine ≥ 20.10
- Docker Compose plugin v2 (`docker compose` not `docker-compose`)
- Ports `6432` (PgBouncer), `6379` (Redis), `8004` (RedisInsight), and `127.0.0.1:5432` (Postgres direct) available on the host

---

## First-Time Setup

### 1. Fill in `.env`

All `REQUIRED` fields must be set before starting. Open `Docker/.env` and populate the PostgreSQL, PgBouncer, Redis, and Backup sections:

```bash
# ── PostgreSQL ────────────────────
POSTGRES_USER=myapp              # Do not use 'postgres'
POSTGRES_PASSWORD=<strong-password>
POSTGRES_DB=myapp_db

# ── PgBouncer ─────────────────────
PGBOUNCER_AUTH_USER=pgbouncer    # Default — change if needed
PGBOUNCER_AUTH_PASSWORD=<strong-password>
PGBOUNCER_PORT=6432

# ── Redis ─────────────────────────
REDIS_PASSWORD=<strong-password>

# ── Backup ────────────────────────
BACKUP_SCHEDULE=0 2 * * *       # Daily at 02:00 UTC
BACKUP_KEEP_DAYS=7
```

**Generating strong passwords:**
```bash
openssl rand -base64 32
```

**Using HashiCorp Vault instead of `.env`:**
Export secrets as environment variables before running compose:
```bash
export POSTGRES_PASSWORD=$(vault kv get -field=db.password secret/myapp)
export PGBOUNCER_AUTH_PASSWORD=$(vault kv get -field=pgbouncer.password secret/myapp)
# ... etc.
docker compose -f docker-compose-postgres.yaml up -d
```

### 2. Start the stack

```bash
cd Docker
docker compose -f docker-compose-postgres.yaml up -d
```

Services start in dependency order:
1. `postgres` starts and runs `init.sh` (first boot only)
2. `pgbouncer` starts after postgres is healthy
3. `redis` starts independently
4. `postgres-backup` starts after postgres is healthy

### 3. Verify all services are healthy

```bash
docker compose -f docker-compose-postgres.yaml ps
```

All four services should show `healthy`. If any show `unhealthy`, check logs:
```bash
docker compose -f docker-compose-postgres.yaml logs <service-name>
```

---

## Connecting

### From your application

Connect to **PgBouncer** — not directly to PostgreSQL:

| Parameter | Value |
|-----------|-------|
| Host | `localhost` (or the server IP) |
| Port | `6432` (or `PGBOUNCER_PORT`) |
| Database | your `POSTGRES_DB` value |
| User | your `POSTGRES_USER` value |
| Password | your `POSTGRES_PASSWORD` value |
| SSL mode | `prefer` (or `require` once TLS is configured) |

**Spring Boot (`application.yml`):**
```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:6432/${POSTGRES_DB}
    username: ${POSTGRES_USER}
    password: ${POSTGRES_PASSWORD}
    hikari:
      maximum-pool-size: 10        # Keep low — PgBouncer multiplexes these
      minimum-idle: 2
      connection-timeout: 30000
      idle-timeout: 600000
```

### DBA / admin tools (pgAdmin, psql, DBeaver)

Connect **directly to PostgreSQL** on `127.0.0.1:5432`. This port is bound to loopback only and bypasses PgBouncer pooling — suitable for migrations and admin queries but not for application traffic.

```bash
psql -h 127.0.0.1 -p 5432 -U $POSTGRES_USER -d $POSTGRES_DB
```

### Redis

```bash
redis-cli -h localhost -p 6379 -a $REDIS_PASSWORD
```

RedisInsight web UI is available at `http://localhost:8004`.

---

## PgBouncer Admin Console

PgBouncer exposes a virtual `pgbouncer` database for live monitoring:

```bash
psql -h localhost -p 6432 -U $PGBOUNCER_AUTH_USER pgbouncer
```

Useful commands inside the console:

```sql
-- Pool utilisation: active/idle/waiting connections per (db, user) pair
SHOW POOLS;

-- Aggregate throughput and latency statistics
SHOW STATS;

-- All active client connections
SHOW CLIENTS;

-- All server-side connections (connections to PostgreSQL)
SHOW SERVERS;

-- Current configuration values
SHOW CONFIG;

-- Reload pgbouncer.ini without dropping connections
RELOAD;

-- Gracefully close idle server connections in a pool
RECONNECT <database>;
```

---

## Logging

All services log to Docker's `json-file` driver with rotation configured per service:

| Service | Max size | Files kept | Total cap |
|---------|----------|------------|-----------|
| postgres | 100 MB | 10 | 1 GB |
| pgbouncer | 50 MB | 10 | 500 MB |
| redis | 50 MB | 5 | 250 MB |
| postgres-backup | 20 MB | 5 | 100 MB |

**Tail logs in real time:**
```bash
# All services
docker compose -f docker-compose-postgres.yaml logs -f

# Single service
docker logs -f postgres
docker logs -f pgbouncer
docker logs -f postgres-backup
```

**PostgreSQL logs what to expect:**
- All queries slower than 1 second (`log_min_duration_statement = 1000`)
- Every connection open and close (`log_connections`, `log_disconnections`)
- Lock waits (`log_lock_waits`)
- Temporary file creation (`log_temp_files`)
- Autovacuum runs over 250 ms (`log_autovacuum_min_duration`)
- Checkpoint activity (`log_checkpoints`)

**Sample slow query log entry:**
```
2024-03-14 02:15:32 UTC [47]: [3-1] user=myapp,db=myapp_db,app=springboot,client=172.18.0.5 LOG:  duration: 1243.891 ms  statement: SELECT ...
```

---

## Backups

### Schedule and location

Backups run inside the `postgres-backup` container on the cron schedule set by `BACKUP_SCHEDULE` (default: `0 2 * * *` = daily at 02:00 UTC). Dump files are written to `Docker/backups/` on the **host machine** via a bind mount, so they persist independently of Docker volumes.

**Format:** `pg_<database>_<YYYYMMDD_HHMMSS>.dump`
**Compression:** `pg_dump --format=custom --compress=9` (binary, ~60–80% smaller than plain SQL)

**Retention:** The `BACKUP_KEEP_DAYS` most recent files are kept. Older files are deleted automatically after each run.

### Trigger a manual backup immediately

```bash
docker exec postgres-backup /bin/sh /scripts/backup.sh
```

### Monitor backup logs

```bash
# Live cron output
docker logs -f postgres-backup

# Persistent log file inside the container
docker exec postgres-backup cat /var/log/backup/backup.log
```

### Restore from a backup file

```bash
# List available backups
ls -lh Docker/backups/

# Restore to the running PostgreSQL container
# WARNING: this overwrites all data in $POSTGRES_DB
docker exec -i postgres pg_restore \
  --host=localhost \
  --username=$POSTGRES_USER \
  --dbname=$POSTGRES_DB \
  --clean \
  --if-exists \
  --no-owner \
  --verbose \
  /backups/pg_myapp_db_20240314_020001.dump

# Alternatively, restore to a different database (safer for testing)
docker exec postgres psql -U $POSTGRES_USER -c "CREATE DATABASE myapp_db_restore;"
docker exec -i postgres pg_restore \
  --host=localhost \
  --username=$POSTGRES_USER \
  --dbname=myapp_db_restore \
  --no-owner \
  /backups/pg_myapp_db_20240314_020001.dump
```

> **Note:** The backup file lives on the host at `Docker/backups/`. The `pg_restore` command above runs inside the `postgres` container, so the path `/backups/...` must be reachable from inside it. Either copy the file in with `docker cp`, or mount the backups directory into the postgres container temporarily.

**Simpler restore using the host `psql`:**
```bash
pg_restore \
  --host=127.0.0.1 \
  --port=5432 \
  --username=$POSTGRES_USER \
  --dbname=$POSTGRES_DB \
  --clean \
  --if-exists \
  --no-owner \
  Docker/backups/pg_myapp_db_20240314_020001.dump
```

---

## Configuration Tuning

### Adjusting pool size

Edit `Docker/postgres/pgbouncer.ini` then reload without downtime:

```bash
docker exec pgbouncer pgbouncer -R /etc/pgbouncer/pgbouncer.ini
# or from the admin console:
# psql -h localhost -p 6432 -U pgbouncer pgbouncer -c "RELOAD;"
```

Key values to tune for your workload:

| Setting | Default | When to change |
|---------|---------|----------------|
| `default_pool_size` | 25 | Increase if `SHOW POOLS` shows `cl_waiting > 0` consistently |
| `max_client_conn` | 1000 | Increase for very high concurrency apps |
| `idle_transaction_timeout` | 30s | Decrease to catch runaway transactions sooner |
| `query_wait_timeout` | 120s | Decrease to fail fast when the pool is exhausted |

### Adjusting PostgreSQL memory

Edit `Docker/postgres/postgresql.conf` then apply:

```bash
# Most settings take effect with a reload (no restart needed)
docker exec postgres psql -U $POSTGRES_USER -c "SELECT pg_reload_conf();"

# Settings marked with context 'postmaster' require a restart
docker compose -f docker-compose-postgres.yaml restart postgres
```

Rule of thumb for a dedicated database server:

| RAM | `shared_buffers` | `effective_cache_size` | `work_mem` |
|-----|-----------------|----------------------|-----------|
| 2 GB | 512 MB | 1.5 GB | 16 MB |
| 4 GB | 1 GB | 3 GB | 32 MB |
| 8 GB | 2 GB | 6 GB | 64 MB |
| 16 GB | 4 GB | 12 GB | 128 MB |

---

## Common Operations

### Create a new application database user

```bash
psql -h 127.0.0.1 -p 5432 -U $POSTGRES_USER -d $POSTGRES_DB <<SQL
  CREATE ROLE appuser WITH LOGIN PASSWORD 'strong-password';
  GRANT CONNECT ON DATABASE myapp_db TO appuser;
  GRANT USAGE ON SCHEMA public TO appuser;
  GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO appuser;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO appuser;
SQL
```

### Reload pg_hba.conf without restart

```bash
docker exec postgres psql -U $POSTGRES_USER -c "SELECT pg_reload_conf();"
```

### Rotate the PgBouncer auth user password

1. Update `PGBOUNCER_AUTH_PASSWORD` in `.env`
2. Restart PgBouncer (regenerates `userlist.txt`) and update the role in PostgreSQL:

```bash
docker compose -f docker-compose-postgres.yaml restart pgbouncer
psql -h 127.0.0.1 -p 5432 -U $POSTGRES_USER \
  -c "ALTER ROLE pgbouncer WITH PASSWORD 'new-password';"
```

### Check for long-running queries

```bash
psql -h 127.0.0.1 -p 5432 -U $POSTGRES_USER -d $POSTGRES_DB <<SQL
  SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
  FROM pg_stat_activity
  WHERE (now() - pg_stat_activity.query_start) > interval '30 seconds'
    AND state != 'idle'
  ORDER BY duration DESC;
SQL
```

### Terminate a stuck query

```bash
# Graceful cancel (sends SIGINT to backend)
psql -h 127.0.0.1 -p 5432 -U $POSTGRES_USER \
  -c "SELECT pg_cancel_backend(<pid>);"

# Forceful termination (sends SIGTERM)
psql -h 127.0.0.1 -p 5432 -U $POSTGRES_USER \
  -c "SELECT pg_terminate_backend(<pid>);"
```

### Stop and start the stack

```bash
# Stop all containers (data volumes preserved)
docker compose -f docker-compose-postgres.yaml down

# Start again
docker compose -f docker-compose-postgres.yaml up -d

# Full teardown including volumes (DESTROYS ALL DATA)
docker compose -f docker-compose-postgres.yaml down -v
```

---

## Enabling TLS (Production Requirement)

TLS stubs are in `pgbouncer.ini`. To enable:

1. Obtain a certificate (Let's Encrypt, your CA, or self-signed for internal use).
2. Place `server.crt`, `server.key`, and `ca.crt` in `Docker/postgres/tls/` (add to `.gitignore`).
3. Mount them into PgBouncer in `docker-compose-postgres.yaml`:
   ```yaml
   volumes:
     - ./postgres/tls/server.crt:/etc/pgbouncer/server.crt:ro
     - ./postgres/tls/server.key:/etc/pgbouncer/server.key:ro
     - ./postgres/tls/ca.crt:/etc/pgbouncer/ca.crt:ro
   ```
4. Uncomment the TLS block in `pgbouncer.ini`:
   ```ini
   client_tls_sslmode = require
   client_tls_cert_file = /etc/pgbouncer/server.crt
   client_tls_key_file  = /etc/pgbouncer/server.key
   server_tls_sslmode   = verify-full
   server_tls_ca_file   = /etc/pgbouncer/ca.crt
   ```
5. Restart PgBouncer: `docker compose -f docker-compose-postgres.yaml restart pgbouncer`

---

## Healthcheck Reference

| Service | Check | Interval | Retries |
|---------|-------|----------|---------|
| postgres | `pg_isready -U $POSTGRES_USER -d $POSTGRES_DB` | 10s | 5 |
| pgbouncer | `pgrep pgbouncer` | 10s | 5 |
| redis | `redis-cli -a $REDIS_PASSWORD ping` | 10s | 5 |
| postgres-backup | `pgrep crond` | 30s | 3 |
