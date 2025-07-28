#!/bin/bash

set -e

echo "🔐 Initializing Vault..."

# Wait for Vault to be accessible
until curl -s http://localhost:8200/v1/sys/health | grep -q 'initialized'; do
  echo "⏳ Waiting for Vault to be ready..."
  sleep 3
done

# Login using root token
export VAULT_ADDR='http://localhost:8300'
export VAULT_TOKEN=root

# Enable KV v2 if not enabled
vault secrets enable -path=secret kv-v2 || true

# Write initial secrets
vault kv put secret/auth \
  jwt.secret="77xxmV7NVGOw9xzlCT" \
  db.username="bVLirDsGGGWgwpQSfA" \
  db.password="1KakrKeJcu57xeu8eU"

echo "✅ Vault initialized with base secrets."
