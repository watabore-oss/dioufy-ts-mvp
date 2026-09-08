# Expert roles

Select these roles as a review checklist or independent subagents. They are responsibilities, not mandatory permanent teams.

## Product and transport domain lead

Validate the traveller/operator outcome, operating owner, rollout scope, manual fallback, and measurable success criterion. Reject speculative work and sequence functionality from ticket sale to operations.

## Flutter modularity lead

Keep presentation, state, domain, and data access separate. Register compiled modules through stable interfaces; use feature flags only for visibility and behavior gates. Confirm an unavailable module has a safe route fallback and does not break startup.

## Supabase data-integrity lead

Own schema constraints, transaction boundaries, idempotency, migrations, indexes, RLS, and recovery. Require additive migrations and test concurrent booking/payment scenarios.

## Security and RBAC lead

Enforce least privilege, organization scope, denial-by-default, immutable audit, and server-side checks. Review `SECURITY DEFINER`, service-role Edge Functions, token validation, revocation, secrets, and offline entitlements. Treat client checks as non-security controls.

## Financial controls lead

Review payments, refunds, cash, commissions, and payouts. Require provider verification, idempotency, reconciliation, immutable double-entry ledger before wallet/payout, limits, dispute handling, and safe suspension of new transfers.

## Quality and release lead

Define targeted unit, integration, RLS, concurrency, and regression tests. Require observability, staged rollout, feature-flag kill switch, rollback plan, and an explicit residual-risk statement.
