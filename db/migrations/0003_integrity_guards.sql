BEGIN;

CREATE OR REPLACE FUNCTION core.enforce_project_permission_org_scope()
RETURNS trigger AS $$
DECLARE
  project_org UUID;
  user_org UUID;
BEGIN
  SELECT org_id INTO project_org FROM core.projects WHERE id = NEW.project_id;
  SELECT org_id INTO user_org FROM auth.users WHERE id = NEW.user_id;

  IF project_org IS NULL OR user_org IS NULL THEN
    RAISE EXCEPTION 'Invalid project_id or user_id for project permission';
  END IF;

  IF project_org <> user_org THEN
    RAISE EXCEPTION 'Cross-org project permission assignment is forbidden';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_project_permission_org_scope ON core.project_permissions;
CREATE TRIGGER trg_project_permission_org_scope
BEFORE INSERT OR UPDATE ON core.project_permissions
FOR EACH ROW
EXECUTE FUNCTION core.enforce_project_permission_org_scope();

CREATE OR REPLACE FUNCTION core.enforce_share_policies()
RETURNS trigger AS $$
DECLARE
  org_public_enabled BOOLEAN;
  project_org UUID;
  project_status TEXT;
  project_visibility TEXT;
  creator_org UUID;
BEGIN
  SELECT p.org_id, p.status, p.visibility
    INTO project_org, project_status, project_visibility
    FROM core.projects p
   WHERE p.id = NEW.project_id;

  IF project_org IS NULL THEN
    RAISE EXCEPTION 'Share project does not exist';
  END IF;

  IF NEW.org_id <> project_org THEN
    RAISE EXCEPTION 'Share org_id must match project org_id';
  END IF;

  IF NEW.created_by IS NOT NULL THEN
    SELECT u.org_id INTO creator_org FROM auth.users u WHERE u.id = NEW.created_by;
    IF creator_org IS NULL OR creator_org <> NEW.org_id THEN
      RAISE EXCEPTION 'Share creator must belong to share org';
    END IF;
  END IF;

  IF NEW.type = 'public' THEN
    SELECT o.public_sharing_enabled INTO org_public_enabled FROM core.organizations o WHERE o.id = NEW.org_id;
    IF org_public_enabled IS DISTINCT FROM TRUE THEN
      RAISE EXCEPTION 'Public share forbidden because org public sharing is disabled';
    END IF;

    IF project_status <> 'published' OR project_visibility <> 'public' THEN
      RAISE EXCEPTION 'Public share requires published and public project';
    END IF;
  END IF;

  IF NEW.type IN ('internal', 'public') AND NEW.expires_at IS NOT NULL THEN
    RAISE EXCEPTION 'Internal/public shares must not carry token expiry';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_share_policy_enforcement ON core.shares;
CREATE TRIGGER trg_share_policy_enforcement
BEFORE INSERT OR UPDATE ON core.shares
FOR EACH ROW
EXECUTE FUNCTION core.enforce_share_policies();

CREATE OR REPLACE FUNCTION assets.enforce_asset_org_scope()
RETURNS trigger AS $$
DECLARE
  project_org UUID;
  owner_org UUID;
BEGIN
  IF NEW.project_id IS NOT NULL THEN
    SELECT p.org_id INTO project_org FROM core.projects p WHERE p.id = NEW.project_id;
    IF project_org IS NULL OR project_org <> NEW.org_id THEN
      RAISE EXCEPTION 'Asset project org mismatch';
    END IF;
  END IF;

  IF NEW.owner_user_id IS NOT NULL THEN
    SELECT u.org_id INTO owner_org FROM auth.users u WHERE u.id = NEW.owner_user_id;
    IF owner_org IS NULL OR owner_org <> NEW.org_id THEN
      RAISE EXCEPTION 'Asset owner org mismatch';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_asset_org_scope ON assets.assets;
CREATE TRIGGER trg_asset_org_scope
BEFORE INSERT OR UPDATE ON assets.assets
FOR EACH ROW
EXECUTE FUNCTION assets.enforce_asset_org_scope();

CREATE OR REPLACE FUNCTION ops.enforce_viewer_session_scope()
RETURNS trigger AS $$
DECLARE
  project_org UUID;
  share_org UUID;
  share_project UUID;
BEGIN
  SELECT p.org_id INTO project_org FROM core.projects p WHERE p.id = NEW.project_id;
  IF project_org IS NULL OR project_org <> NEW.org_id THEN
    RAISE EXCEPTION 'Viewer session project/org mismatch';
  END IF;

  IF NEW.share_id IS NOT NULL THEN
    SELECT s.org_id, s.project_id INTO share_org, share_project FROM core.shares s WHERE s.id = NEW.share_id;

    IF share_org IS NULL THEN
      RAISE EXCEPTION 'Viewer session share does not exist';
    END IF;

    IF share_org <> NEW.org_id OR share_project <> NEW.project_id THEN
      RAISE EXCEPTION 'Viewer session share scope mismatch';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_viewer_session_scope ON ops.viewer_sessions;
CREATE TRIGGER trg_viewer_session_scope
BEFORE INSERT OR UPDATE ON ops.viewer_sessions
FOR EACH ROW
EXECUTE FUNCTION ops.enforce_viewer_session_scope();

COMMIT;
