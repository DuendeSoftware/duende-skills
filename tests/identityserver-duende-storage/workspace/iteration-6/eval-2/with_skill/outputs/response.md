**No. Duende Storage does not replace EF Core, and you shouldn't migrate just for the sake of it.**

- Duende Storage is an **opt-in preview** (IdentityServer 8.1 previews). The EF Core provider (classic tables, `AddConfigurationStore`/`AddOperationalStore`) stays fully supported. The EF tables aren't deprecated.
- Preview means packages, APIs, schemas and behavior may change before GA.
- Your existing store interfaces (`IClientStore`, etc.) are the same either way.

**Migrate only if you need what Duende Storage adds:**
- Supported admin service APIs (`IClientAdmin`, `IApiScopeAdmin`, `IIdentityProviderAdmin`, ...)
- Schema-validated custom properties (data extension schemas)
- Consistent querying and optimistic concurrency (versions) across databases
- Storage pools (for Spaces)
- Shared persistence with other Duende products, e.g. User Management

**If you do:**
- There is no automated or in-place migration, because the schemas differ.
- Configuration can be exported through the EF contexts and imported through the admin APIs (scopes and identity resources first).
- Client secrets are one-way hashes in EF, so they must be re-provisioned from a secure source or rotated.
- Operational data has no transfer tool. Plan a controlled reset in a maintenance window.
- Rehearse on a production-like copy, keep a rollback window, and don't dual-write.

Since your app works and this is a preview, staying on EF Core is the reasonable default. Revisit when the feature goes GA or you need one of the capabilities above.
