# Phase 1 Implementation Roadmap (Security-First, Zero-Ambiguity)

This roadmap converts the finalized Phase 1 specification into an execution sequence that is dependency-locked and backend-first.

## 1) Phase 1 Scope

Phase 1 covers:
- Database schema + constraints + security triggers.
- Authentication/authorization middleware.
- Share validation endpoint.
- Asset signed URL endpoint.
- Audit immutability and core logging paths.
- Unit/integration/e2e/load/security validation targets.

## 2) Dependency-Locked Build Order

1. Database schema migration and verification.
2. Auth middleware (`JWT`, org isolation, role gates).
3. Permission precedence enforcement.
4. Share validation service (`GET /shares/validate`).
5. Viewer session issuance + revocation checks.
6. Asset signed URL service (`GET /assets/{id}/signed-url`).
7. Error semantics and leakage prevention.
8. Revocation cascades + cleanup routines.
9. Project deletion and cascade behavior.
10. End-to-end and load/security testing.

If a prerequisite step is incomplete, downstream steps are blocked.

## 3) Delivery Plan (3 Weeks)

### Week 1 — Database + Authentication Foundation

#### Day 1–2: Database Setup
- Execute Phase 1 schema migration in staging.
- Verify tables, indexes, and triggers created successfully.
- Validate FK integrity and cascade behavior.
- Validate append-only behavior for audit logs.

#### Day 3–4: Auth Middleware
- Implement `authMiddleware` with JWT signature/issuer/audience/expiry validation.
- Implement `orgGuard` (org mismatch => `404` to avoid resource discovery).
- Implement `requireRole` for protected endpoints.
- Add unit tests with target coverage `>= 80%` for auth modules.

#### Day 5: Role Precedence
- Implement `getEffectivePermission()` logic.
- Enforce floor constraint: global viewer cannot escalate via project permission.
- Test all role combinations.

### Week 2 — Share + Asset Endpoints

#### Day 6–7: Share Validation Endpoint
- Implement `GET /shares/validate` (token or shareId path).
- Token validation: hash-and-compare against stored hash.
- Create transient viewer session with expiry.
- Enforce revocation consistency (`revocation_version` checks).
- Add integration tests for success and all deny/error paths.

#### Day 8–9: Asset Signing Endpoint
- Implement `GET /assets/{id}/signed-url`.
- Validate viewer session + scope on each request.
- Generate signed URL with short TTL (`60–300s`, default 5 min max by policy).
- Write audit events for asset access attempts.
- Add integration tests for happy path and revoked/expired denied path.

#### Day 10: Errors + Edge Cases
- Enforce `401/403/404` semantics consistently.
- Prevent metadata leakage on unauthorized access.
- Handle session expiry and forced revocation races.
- Implement org/user rate limits.

### Week 3 — Revocation, Cascades, Full Validation

#### Day 11–12: Revocation + Session Controls
- Validate share revocation trigger behavior.
- Validate viewer session immediate invalidation.
- Add concurrent session guardrails and expiry cleanup job.

#### Day 13–14: Project Deletion + Cascades
- Implement `DELETE /projects/{id}` (owner-only).
- Validate deletion cascades (shares, permissions, sessions, assets).
- Ensure deletion audit events are emitted.

#### Day 15: Full Integration
- E2E: SSO -> project access -> share -> viewer -> signed asset access.
- Exercise all explicit failure paths.
- Run concurrency/load scenario and review alerts/logs.

## 4) Definition of Done (Phase 1)

### Database
- [ ] Schema migrated successfully in staging.
- [ ] FK + cascade constraints verified.
- [ ] Security triggers verified (revocation, state-machine, org scope).
- [ ] Audit log immutability enforced.

### Auth + Permissions
- [ ] JWT auth validation active on protected routes.
- [ ] Org isolation checks active (`404` on mismatch).
- [ ] Role checks active and precedence floor verified.
- [ ] Disabled-user lockout enforced.

### Share + Viewer Session
- [ ] `GET /shares/validate` implemented and tested.
- [ ] Revoked/expired links return `403`.
- [ ] Viewer sessions short-lived and revocation-aware.

### Assets
- [ ] `GET /assets/{id}/signed-url` implemented and tested.
- [ ] Only signed URLs returned, never raw file data.
- [ ] Scope checks applied per request.

### Audit + Observability
- [ ] Critical actions logged with org scope.
- [ ] Audit logs append-only.
- [ ] Alert hooks configured for anomaly cases.

### Testing
- [ ] Unit coverage target met for auth/permission modules.
- [ ] Integration tests cover success + denied/error cases.
- [ ] E2E flow validated.
- [ ] Load/security test pass criteria met.

## 5) Critical Invariants to Re-Check Before Promotion

1. Every protected query is org-scoped.
2. Share revocation invalidates viewer access immediately.
3. Global role floor prevents privilege escalation.
4. 401/403/404 semantics do not leak resource existence.
5. Audit logs are append-only and complete for critical actions.

## 6) Immediate Next Task

Start with the database migration execution in staging and verification artifacts.
No frontend “login complete” claim is valid until backend auth/session middleware is active.
