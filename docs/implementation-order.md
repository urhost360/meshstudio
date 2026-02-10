# UrMeshStudio360 Implementation Order (Dependency Locked)

This repository follows the required locked sequence. Anything out of order is blocked.

## Status

1. ✅ Database schemas + constraints
   - Implemented in `db/migrations/0001`..`0004`.
2. 🟡 Authentication middleware
   - API contracts now defined in `openapi/urmeshstudio360.openapi.yaml` (`/auth/login`, `/auth/session`).
   - Runtime middleware implementation still pending.
3. ⬜ Organization enforcement
4. ⬜ Project permission checks
5. ⬜ ShareLink validation service
6. ⬜ Viewer session service
7. ⬜ Asset signing service
8. ⬜ Viewer runtime (read-only)
9. ⬜ Editor (internal only)
10. ⬜ Logging & audit sinks

## Login screen sequencing

The login screen should only be wired after auth middleware and `/auth/*` endpoints are active; otherwise UI-only auth is insecure and violates backend-source-of-truth requirements.

## Minimum next implementation tasks (in order)

1. Build OIDC auth middleware for Google Workspace / Azure AD / Okta.
2. Implement `POST /auth/login` redirect flow with provider validation.
3. Implement `GET /auth/session` with `401` for unauthenticated requests.
4. Enforce disabled-user lockout on every request path.
5. Add structured audit entries for login + session reads.
