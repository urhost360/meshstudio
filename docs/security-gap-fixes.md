# Security Gap Fixes (Initial Foundation)

This repository had no implementation artifacts, so all required security controls were effectively missing.

## Problems found

1. Missing database schemas and constraints for organization scoping, permissions, share controls, asset isolation, audit logging, and viewer sessions.
2. Missing DB-level guardrail that blocks `draft` projects from becoming `public`.
3. Missing DB-level guardrail enforcing token share requirements (`token_hash` + `expires_at`).
4. Missing revocation propagation mechanism from shares to viewer sessions.
5. Missing explicit migration files to establish deterministic build order beginning with schema constraints.
6. Missing cross-table org-scope enforcement for permission assignments, shares, assets, and viewer sessions.
7. Missing hard stop for public-share eligibility (org toggle + project published/public).
8. Missing DB-level state-machine enforcement for irreversible transitions (project/share/session).
9. Missing explicit API contracts for auth/login/session and core protected endpoints.
10. Missing explicit in-repo order tracking to prevent frontend-first implementation drift.
11. Missing `org_id` column on `core.project_permissions` despite the system rule requiring org scope on every table.
12. Missing explicit DB-level append-only enforcement for `audit.audit_logs`.
13. Missing DB-level uniqueness guarantee to block token hash reuse across shares/projects.

## Fixes implemented

1. Added `0001_foundation.sql` with isolated schemas (`auth`, `core`, `assets`, `audit`, `ops`) and foreign-key-backed table model.
2. Added a `CHECK` on `core.projects` that rejects `status='draft' AND visibility='public'`.
3. Added share constraints requiring token metadata for `type='token'` and enforcing viewer-only permissions.
4. Added revocation version trigger and cascading viewer-session revocation trigger.
5. Added indexes for high-frequency lookup paths (project status, share token hash, org asset queries, viewer sessions by project).
6. Added `0003_integrity_guards.sql` with trigger-based enforcement to deny cross-org references and validate share/public policies.
7. Added `0004_state_machine_guards.sql` to enforce immutable/forward-only state changes.
8. Added `openapi/urmeshstudio360.openapi.yaml` with required JSON/HTTPS contracts for auth, project, share, and asset endpoints.
9. Added `docs/implementation-order.md` to lock sequence and explicitly mark login screen wiring as blocked until auth middleware + `/auth/*` is live.
10. Added `docs/PHASE1_IMPLEMENTATION_ROADMAP.md` with strict execution order and Definition of Done.
11. Added `0005_hardening_fixes.sql` to:
    - add `org_id` to `core.project_permissions`, backfill it, and enforce strict org consistency with project/user,
    - enforce unique non-null `token_hash` across shares,
    - enforce append-only audit logs by blocking update/delete and revoking mutation privileges.

## Notes

- This change intentionally focuses on DB-first and deny-by-default enforcement.
- The next coding step is runtime auth middleware and endpoint implementation against the OpenAPI contract.
