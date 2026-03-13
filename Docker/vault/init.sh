#!/bin/bash

set -e

echo "🔐 Initializing Vault..."

# Wait for Vault to be accessible
until curl -s http://localhost:8200/v1/sys/health | grep -q '"initialized"'; do
  echo "⏳ Waiting for Vault to be ready..."
  sleep 3
done

export VAULT_ADDR='http://localhost:8200'

# Initialize Vault (generates unseal keys and a root token)
# Skip if already initialized
if vault status 2>&1 | grep -q 'Initialized.*true'; then
  echo "Vault is already initialized."
else
  echo "🔑 Initializing Vault (saving keys to vault-init.json — store this securely and delete from disk)"
  vault operator init -format=json > /vault/vault-init.json
  chmod 600 /vault/vault-init.json

  # Unseal using the first three keys
  for i in 0 1 2; do
    UNSEAL_KEY=$(jq -r ".unseal_keys_b64[$i]" /vault/vault-init.json)
    vault operator unseal "$UNSEAL_KEY"
  done
fi

# Authenticate with root token (from the init file, or inject via env for automation)
if [ -f /vault/vault-init.json ]; then
  export VAULT_TOKEN=$(jq -r ".root_token" /vault/vault-init.json)
else
  # In CI/CD, inject VAULT_TOKEN as an environment variable instead
  : "${VAULT_TOKEN:?VAULT_TOKEN must be set}"
fi

# Enable KV v2 if not already enabled
vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV v2 already enabled at secret/"

# Write initial secret placeholders — replace these values before running in production
# Format: vault kv put secret/<path> key="value"
vault kv put secret/auth \
  jwt.secret="${JWT_SECRET:?Set JWT_SECRET env var}" \
  db.username="${DB_USERNAME:?Set DB_USERNAME env var}" \
  db.password="${DB_PASSWORD:?Set DB_PASSWORD env var}"

echo "✅ Vault initialized."
echo "⚠️  Move /vault/vault-init.json to secure offline storage and delete it from the server."
