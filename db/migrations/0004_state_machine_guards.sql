BEGIN;

CREATE OR REPLACE FUNCTION core.touch_project_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_projects_touch_updated_at ON core.projects;
CREATE TRIGGER trg_projects_touch_updated_at
BEFORE UPDATE ON core.projects
FOR EACH ROW
EXECUTE FUNCTION core.touch_project_updated_at();

CREATE OR REPLACE FUNCTION core.enforce_project_state_transitions()
RETURNS trigger AS $$
BEGIN
  IF OLD.status = 'draft' AND NEW.status NOT IN ('draft', 'published') THEN
    RAISE EXCEPTION 'Invalid project state transition';
  END IF;

  IF OLD.status = 'published' AND NEW.status NOT IN ('published', 'archived') THEN
    RAISE EXCEPTION 'Invalid project state transition';
  END IF;

  IF OLD.status = 'archived' AND NEW.status <> 'archived' THEN
    RAISE EXCEPTION 'Invalid project state transition';
  END IF;

  IF NEW.visibility = 'public' AND NEW.status <> 'published' THEN
    RAISE EXCEPTION 'Public visibility requires published status';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_project_state_machine ON core.projects;
CREATE TRIGGER trg_project_state_machine
BEFORE UPDATE ON core.projects
FOR EACH ROW
EXECUTE FUNCTION core.enforce_project_state_transitions();

CREATE OR REPLACE FUNCTION core.enforce_share_state_machine()
RETURNS trigger AS $$
BEGIN
  IF OLD.revoked_at IS NOT NULL AND NEW.revoked_at IS NULL THEN
    RAISE EXCEPTION 'Revoked share cannot be un-revoked';
  END IF;

  IF NEW.type <> OLD.type THEN
    RAISE EXCEPTION 'Share type is immutable';
  END IF;

  IF NEW.project_id <> OLD.project_id OR NEW.org_id <> OLD.org_id THEN
    RAISE EXCEPTION 'Share scope fields are immutable';
  END IF;

  IF NEW.type = 'token' AND NEW.expires_at <= now() THEN
    RAISE EXCEPTION 'Token share expiry must be in the future';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_share_state_machine ON core.shares;
CREATE TRIGGER trg_share_state_machine
BEFORE UPDATE ON core.shares
FOR EACH ROW
EXECUTE FUNCTION core.enforce_share_state_machine();

CREATE OR REPLACE FUNCTION core.enforce_share_insert_defaults()
RETURNS trigger AS $$
BEGIN
  IF NEW.type = 'token' AND NEW.expires_at <= now() THEN
    RAISE EXCEPTION 'Token share expiry must be in the future';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_share_insert_guard ON core.shares;
CREATE TRIGGER trg_share_insert_guard
BEFORE INSERT ON core.shares
FOR EACH ROW
EXECUTE FUNCTION core.enforce_share_insert_defaults();

CREATE OR REPLACE FUNCTION ops.enforce_viewer_session_state_machine()
RETURNS trigger AS $$
BEGIN
  IF NEW.expires_at <= now() THEN
    RAISE EXCEPTION 'Viewer session expiry must be in the future';
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.revoked = TRUE AND NEW.revoked = FALSE THEN
    RAISE EXCEPTION 'Revoked viewer session cannot be reactivated';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_viewer_session_state_machine ON ops.viewer_sessions;
CREATE TRIGGER trg_viewer_session_state_machine
BEFORE INSERT OR UPDATE ON ops.viewer_sessions
FOR EACH ROW
EXECUTE FUNCTION ops.enforce_viewer_session_state_machine();

COMMIT;
