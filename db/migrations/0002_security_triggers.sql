BEGIN;

CREATE OR REPLACE FUNCTION core.increment_share_revocation()
RETURNS trigger AS $$
BEGIN
  IF (TG_OP = 'UPDATE' AND NEW.revoked_at IS NOT NULL AND OLD.revoked_at IS NULL) THEN
    NEW.revocation_version = OLD.revocation_version + 1;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_share_revocation ON core.shares;
CREATE TRIGGER trg_share_revocation
BEFORE UPDATE ON core.shares
FOR EACH ROW
EXECUTE FUNCTION core.increment_share_revocation();

CREATE OR REPLACE FUNCTION ops.revoke_viewer_sessions_on_share_revoke()
RETURNS trigger AS $$
BEGIN
  IF NEW.revocation_version > OLD.revocation_version THEN
    UPDATE ops.viewer_sessions
       SET revoked = TRUE,
           revocation_version = NEW.revocation_version
     WHERE share_id = NEW.id
       AND revoked = FALSE;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_revoke_viewer_sessions ON core.shares;
CREATE TRIGGER trg_revoke_viewer_sessions
AFTER UPDATE ON core.shares
FOR EACH ROW
EXECUTE FUNCTION ops.revoke_viewer_sessions_on_share_revoke();

COMMIT;
