BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS assets;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS ops;

CREATE TABLE core.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  domain TEXT NOT NULL UNIQUE,
  sso_provider JSONB NOT NULL,
  public_sharing_enabled BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE auth.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL,
  email TEXT NOT NULL,
  name TEXT,
  avatar_url TEXT,
  auth_provider TEXT NOT NULL,
  provider_user_id TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'editor', 'viewer')),
  disabled_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_login_at TIMESTAMPTZ NULL,
  UNIQUE (org_id, email),
  UNIQUE (auth_provider, provider_user_id),
  FOREIGN KEY (org_id) REFERENCES core.organizations(id) ON DELETE CASCADE
);

CREATE TABLE core.projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL CHECK (status IN ('draft', 'published', 'archived')) DEFAULT 'draft',
  visibility TEXT NOT NULL CHECK (visibility IN ('private', 'public')) DEFAULT 'private',
  owner_user_id UUID NULL,
  scene_blob_path TEXT NULL,
  interaction_blob_path TEXT NULL,
  ui_blob_path TEXT NULL,
  thumbnail_path TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (org_id) REFERENCES core.organizations(id) ON DELETE CASCADE,
  FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE SET NULL,
  CHECK (NOT (status = 'draft' AND visibility = 'public'))
);

CREATE INDEX idx_projects_org_status ON core.projects (org_id, status);

CREATE TABLE core.project_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL,
  user_id UUID NOT NULL,
  permission TEXT NOT NULL CHECK (permission IN ('owner', 'editor', 'viewer')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (project_id, user_id),
  FOREIGN KEY (project_id) REFERENCES core.projects(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE core.shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL,
  org_id UUID NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('internal', 'token', 'public')),
  token_hash TEXT NULL,
  expires_at TIMESTAMPTZ NULL,
  permissions TEXT NOT NULL DEFAULT 'viewer' CHECK (permissions = 'viewer'),
  created_by UUID NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ NULL,
  last_accessed_at TIMESTAMPTZ NULL,
  revocation_version BIGINT NOT NULL DEFAULT 0,
  FOREIGN KEY (project_id) REFERENCES core.projects(id) ON DELETE CASCADE,
  FOREIGN KEY (org_id) REFERENCES core.organizations(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL,
  CHECK (
    (type = 'token' AND token_hash IS NOT NULL AND expires_at IS NOT NULL)
    OR (type IN ('internal', 'public') AND token_hash IS NULL)
  )
);

CREATE INDEX idx_shares_project ON core.shares (project_id);
CREATE INDEX idx_shares_tokenhash ON core.shares (token_hash);

CREATE TABLE assets.assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL,
  project_id UUID NULL,
  owner_user_id UUID NULL,
  filename TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  content_type TEXT NOT NULL,
  size_bytes BIGINT NOT NULL CHECK (size_bytes >= 0),
  polycount BIGINT NULL,
  width INT NULL,
  height INT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (org_id) REFERENCES core.organizations(id) ON DELETE CASCADE,
  FOREIGN KEY (project_id) REFERENCES core.projects(id) ON DELETE CASCADE,
  FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX idx_assets_org ON assets.assets (org_id);

CREATE TABLE audit.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL,
  actor_user_id UUID NULL,
  actor_type TEXT NOT NULL CHECK (actor_type IN ('user', 'token', 'system')),
  action TEXT NOT NULL,
  target_type TEXT NULL,
  target_id UUID NULL,
  ip TEXT NULL,
  user_agent TEXT NULL,
  meta JSONB NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (org_id) REFERENCES core.organizations(id) ON DELETE CASCADE
);

CREATE TABLE ops.viewer_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  share_id UUID NULL,
  project_id UUID NOT NULL,
  org_id UUID NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('internal', 'token', 'public')),
  permissions JSONB NOT NULL,
  asset_scope JSONB NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked BOOLEAN NOT NULL DEFAULT false,
  revocation_version BIGINT NOT NULL DEFAULT 0,
  FOREIGN KEY (share_id) REFERENCES core.shares(id) ON DELETE SET NULL,
  FOREIGN KEY (project_id) REFERENCES core.projects(id) ON DELETE CASCADE,
  FOREIGN KEY (org_id) REFERENCES core.organizations(id) ON DELETE CASCADE
);

CREATE INDEX idx_viewer_sessions_project ON ops.viewer_sessions (project_id);

COMMIT;
