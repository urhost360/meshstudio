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

## Fixes implemented

1. Added `0001_foundation.sql` with isolated schemas (`auth`, `core`, `assets`, `audit`, `ops`) and foreign-key-backed table model.
2. Added a `CHECK` on `core.projects` that rejects `status='draft' AND visibility='public'`.
3. Added share constraints requiring token metadata for `type='token'` and enforcing viewer-only permissions.
4. Added revocation version trigger and cascading viewer-session revocation trigger.
5. Added indexes for high-frequency lookup paths (project status, share token hash, org asset queries, viewer sessions by project).
6. Added `0003_integrity_guards.sql` with trigger-based enforcement to deny cross-org references and validate share/public policies:
   - project-permission user/project org match,
   - share org consistency + creator org consistency,
   - public-share allowed only when org has public sharing enabled and project is `published` + `public`,
   - assets constrained to matching org for project/owner,
   - viewer sessions constrained to matching project/share/org scope.

## Notes

- This change intentionally focuses on DB-first and deny-by-default enforcement.
- API and middleware enforcement should be layered next in code, with explicit 401/403/404 handling and structured audit sinks.
