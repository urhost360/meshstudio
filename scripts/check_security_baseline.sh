#!/usr/bin/env bash
set -euo pipefail

sql1="db/migrations/0001_foundation.sql"
sql2="db/migrations/0002_security_triggers.sql"
sql3="db/migrations/0003_integrity_guards.sql"

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
)

for pattern in "${required_patterns[@]}"; do
  if ! rg -F "$pattern" "$sql1" "$sql2" "$sql3" >/dev/null; then
    echo "Missing required security pattern: $pattern" >&2
    exit 1
  fi
done

echo "Security baseline checks passed."
