---
name: dioufy-safe-delivery
description: Safely analyze, plan, implement, and review Dioufy-TS Flutter and Supabase changes. Use for any product, payment, RBAC, booking, ticketing, data-model, Edge Function, or module/feature-flag change where impact analysis, proportional design, data integrity, and production safety are required.
---

# Dioufy Safe Delivery

Use a small virtual review team rather than adding permanent process or infrastructure. Select only the specialists relevant to the request from `references/expert-roles.md`.

## Non-negotiable principles

- Preserve confirmed bookings, tickets, payments, audits, and financial history. Disabling a module stops new work; it never deletes historical data.
- Treat Flutter guards as user experience only. Enforce authorization, tenancy, and financial invariants in Postgres/RLS/RPC or trusted Edge Functions.
- Prefer a modular monolith. Do not create a microservice, plugin runtime, queue, cache, or abstraction unless the current requirement and evidence justify it.
- Keep modules compiled into Flutter. Use server-authoritative feature flags to expose already-shipped capability; do not load arbitrary executable code at runtime.
- Make every state-changing network action idempotent and safe under retry.
- Never ship a privilege, payment, ticket-validation, or data migration change without targeted automated checks.

## Workflow

### 1. Discover before editing

Read the applicable `AGENTS.md`, inspect the current implementation, database schema, Edge Functions, tests, and git status. State known facts, assumptions, and unknowns. Do not invent existing tests, modules, or schema fields.

### 2. Classify risk and select reviewers

Classify the request:

| Risk | Examples | Required review |
|---|---|---|
| Low | text, isolated visual UI | Flutter engineer |
| Medium | new screen, read query, optional feature flag | Flutter + domain/data engineer |
| High | booking state, QR validation, RBAC, RLS, Edge Function | domain/data + security reviewer |
| Critical | payment, payout, commission ledger, deletion, auth, production migration | all relevant reviewers + explicit implementation plan |

Use the smallest set of roles that covers the risk. For high and critical changes, write a concise impact record before implementation:

`goal; affected modules; data touched; authorization boundary; failure/retry behavior; migration/rollback; tests; observability; why simpler options were rejected`.

### 3. Decide whether to build

Reject or defer work when it lacks a user outcome, has no owner, duplicates an existing capability, or introduces complexity that cannot be tested and operated. Prefer a reversible pilot scoped by organization, route, or user before platform-wide activation.

### 4. Design module boundaries

For a new module, define its stable identifier, owner, inputs/outputs, dependencies, permissions, feature-flag scope, data ownership, audit events, and deactivation behavior. Do not allow cross-module table writes without an explicit service/RPC contract.

For RBAC, use `module.action` permissions plus organization scope. A role hierarchy may restrict role administration but must not replace explicit permission and tenant checks.

### 5. Implement minimally and safely

- Change only the layers required by the accepted impact record.
- Keep UI, domain logic, data access, and server-side authorization separated.
- Validate all server input. Derive the authenticated user from the verified token, not from mutable client input.
- Use additive, reversible database migrations: expand, backfill, validate, then contract later.
- Make feature flags server-authoritative, dependency-aware, audited, and fail-safe. A stale offline cache may support limited read/scan workflows, never privileged or financial mutation.
- Keep role-switch/demo facilities out of production builds.

### 6. Validate and report

Run focused tests first, then the full relevant suite. For high/critical changes, test authorization denial, cross-organization denial, retries/idempotence, concurrency, deactivation, and rollback/migration behavior. Report commands, outcomes, residual risks, and any deliberate deferrals.

## Production gates

Do not release a critical change until all applicable statements are true:

- Database constraints and server checks preserve invariants even if the Flutter app is modified.
- RLS policies or narrowly scoped server RPCs deny cross-tenant access.
- `SECURITY DEFINER` use is minimal, execution is restricted, caller and scope are verified, and unsafe writable schemas are excluded from the search path.
- Payments and payouts are verified from provider-side events, are idempotent, and produce immutable audit/ledger records.
- A disabled module leaves historical records readable and safely drains in-progress work.
- Monitoring can identify failed webhooks, stuck locks, denied authorization, and inconsistent state.

## Project-specific baseline

Before changing booking or payment behavior, inspect the current atomic lock/release/payment flow and its Supabase functions. Before changing UI routing, inspect `lib/main.dart` and the relevant feature. The current MVP has real Supabase functions and tests; do not replace them with unverified demo behavior.

See `references/expert-roles.md` for reviewer responsibilities and `references/module-contract.md` when adding a module or feature flag.
