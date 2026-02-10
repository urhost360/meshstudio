BEGIN;

-- 1) Ensure org_id exists on project_permissions (spec requires org_id on every table).
ALTER TABLE core.project_permissions
  ADD COLUMN IF NOT EXISTS org_id UUID;

UPDATE core.project_permissions pp
   SET org_id = p.org_id
  FROM core.projects p
 WHERE pp.project_id = p.id
   AND pp.org_id IS NULL;

ALTER TABLE core.project_permissions
  ALTER COLUMN org_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_constraint
     WHERE conname = 'project_permissions_org_id_fkey'
       AND conrelid = 'core.project_permissions'::regclass
  ) THEN
    ALTER TABLE core.project_permissions
      ADD CONSTRAINT project_permissions_org_id_fkey
      FOREIGN KEY (org_id) REFERENCES core.organizations(id) ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_project_permissions_org_project_user
  ON core.project_permissions (org_id, project_id, user_id);

CREATE OR REPLACE FUNCTION core.enforce_project_permission_scope_strict()
RETURNS trigger AS $$
DECLARE
  project_org UUID;
  user_org UUID;
BEGIN
  SELECT org_id INTO project_org FROM core.projects WHERE id = NEW.project_id;
  SELECT org_id INTO user_org FROM auth.users WHERE id = NEW.user_id;

  IF project_org IS NULL OR user_org IS NULL THEN
    RAISE EXCEPTION 'Invalid project permission references';
  END IF;

  IF NEW.org_id <> project_org OR NEW.org_id <> user_org THEN
    RAISE EXCEPTION 'project_permissions.org_id must match both project and user org';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_project_permission_scope_strict ON core.project_permissions;
CREATE TRIGGER trg_project_permission_scope_strict
BEFORE INSERT OR UPDATE ON core.project_permissions
FOR EACH ROW
EXECUTE FUNCTION core.enforce_project_permission_scope_strict();

-- 2) Prevent token reuse across projects by preventing token_hash reuse globally.
CREATE UNIQUE INDEX IF NOT EXISTS uq_shares_token_hash_nonnull
  ON core.shares (token_hash)
  WHERE token_hash IS NOT NULL;

-- 3) Make audit logs append-only at the DB layer.
CREATE OR REPLACE FUNCTION audit.block_audit_mutation()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'audit.audit_logs is append-only';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_block_audit_update ON audit.audit_logs;
CREATE TRIGGER trg_block_audit_update
BEFORE UPDATE ON audit.audit_logs
FOR EACH ROW
EXECUTE FUNCTION audit.block_audit_mutation();

DROP TRIGGER IF EXISTS trg_block_audit_delete ON audit.audit_logs;
CREATE TRIGGER trg_block_audit_delete
BEFORE DELETE ON audit.audit_logs
FOR EACH ROW
EXECUTE FUNCTION audit.block_audit_mutation();

REVOKE UPDATE, DELETE, TRUNCATE ON audit.audit_logs FROM PUBLIC;

COMMIT;
