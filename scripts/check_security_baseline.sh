#!/usr/bin/env bash
set -euo pipefail

sql1="db/migrations/0001_foundation.sql"
sql2="db/migrations/0002_security_triggers.sql"
sql3="db/migrations/0003_integrity_guards.sql"
sql4="db/migrations/0004_state_machine_guards.sql"
sql5="db/migrations/0005_hardening_fixes.sql"
api="openapi/urmeshstudio360.openapi.yaml"
order_doc="docs/implementation-order.md"

required_patterns=(
  "CREATE SCHEMA IF NOT EXISTS core;"
  "CREATE TABLE core.organizations"
  "UNIQUE (org_id, email)"
  "UNIQUE (project_id, user_id)"
  "CHECK (NOT (status = 'draft' AND visibility = 'public'))"
  "CHECK (permissions = 'viewer')"
  "CREATE TABLE ops.viewer_sessions"
  "CREATE OR REPLACE FUNCTION core.increment_share_revocation()"
  "CREATE OR REPLACE FUNCTION ops.revoke_viewer_sessions_on_share_revoke()"
  "CREATE OR REPLACE FUNCTION core.enforce_project_permission_org_scope()"
  "CREATE OR REPLACE FUNCTION core.enforce_share_policies()"
  "CREATE OR REPLACE FUNCTION assets.enforce_asset_org_scope()"
  "CREATE OR REPLACE FUNCTION ops.enforce_viewer_session_scope()"
  "CREATE OR REPLACE FUNCTION core.touch_project_updated_at()"
  "CREATE OR REPLACE FUNCTION core.enforce_project_state_transitions()"
  "CREATE OR REPLACE FUNCTION core.enforce_share_state_machine()"
  "CREATE OR REPLACE FUNCTION ops.enforce_viewer_session_state_machine()"
  "ADD COLUMN IF NOT EXISTS org_id UUID;"
  "CREATE OR REPLACE FUNCTION core.enforce_project_permission_scope_strict()"
  "CREATE UNIQUE INDEX IF NOT EXISTS uq_shares_token_hash_nonnull"
  "CREATE OR REPLACE FUNCTION audit.block_audit_mutation()"
  "REVOKE UPDATE, DELETE, TRUNCATE ON audit.audit_logs FROM PUBLIC;"
)

for pattern in "${required_patterns[@]}"; do
  if ! rg -F "$pattern" "$sql1" "$sql2" "$sql3" "$sql4" "$sql5" >/dev/null; then
    echo "Missing required security pattern: $pattern" >&2
    exit 1
  fi
done

api_patterns=(
  "/auth/login:"
  "/auth/session:"
  "/projects/{id}/shares:"
  "/shares/{id}/validate:"
  "/assets/{id}:"
)

for pattern in "${api_patterns[@]}"; do
  if ! rg -F "$pattern" "$api" >/dev/null; then
    echo "Missing required API contract path: $pattern" >&2
    exit 1
  fi
done

if ! rg -F "1. ✅ Database schemas + constraints" "$order_doc" >/dev/null; then
  echo "Build order status doc missing completed step marker" >&2
  exit 1
fi

echo "Security baseline checks passed."
