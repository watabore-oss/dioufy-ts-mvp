# Module contract

Record these fields before adding an independently activatable module:

| Field | Required decision |
|---|---|
| Identifier and owner | Stable machine identifier and accountable product/operations owner. |
| User outcome | Concrete journey and success metric. |
| Dependencies | Core modules and contracts required to activate it. |
| Scope | Platform, organization, route, region, or pilot users. |
| Permissions | Normalized `module.action` permissions and organization constraints. |
| Data | Tables owned, data retained, PII classification, migration path. |
| Operations | Audit events, dashboards, alerts, support and manual fallback. |
| Failure | Retry/idempotency semantics, partial failure handling, degraded mode. |
| Deactivation | Stop-new-work behavior, in-flight drain/hold behavior, historical read access. |
| Validation | Unit, integration, authorization, concurrency, and rollout checks. |

Reject the module or run a limited pilot if any required decision has no safe owner or testable answer.
