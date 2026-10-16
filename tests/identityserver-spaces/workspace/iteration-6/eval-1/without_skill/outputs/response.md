# Per-customer isolation: Multi-Issuer or something else?

I'm not aware of a Duende feature that is a clean fit for "one isolated tenant per deployment unit" beyond what follows, so treat the product-specific parts as things to verify in the docs.

**Multi-issuer / dynamic issuer** (setting `IssuerUri` per request, e.g. from the host or path) only changes the `iss` value in tokens and discovery. Clients, scopes, grants, signing keys and users remain in one shared store. It is a cosmetic separation, not isolation. Use it if tenants just need different issuer URLs.

**For real isolation (separate clients, grants, issuer)** you have two options:

1. **Deployment per customer**: each customer gets its own IdentityServer instance (container/app) with its own configuration database, operational store, signing keys and Data Protection keys. Strongest isolation, simplest to reason about, highest operational cost.
2. **Single deployment with logical multi-tenancy**: a tenant resolver (host or path) chooses a per-tenant issuer, with tenant-aware stores (`TenantId` column on clients, grants etc., or schema/database per tenant), tenant-specific keys and tenant-scoped user lookup. Cheaper to run but you must build/maintain the tenant-aware stores yourself; a missed filter is a cross-tenant leak.

**Recommendation**: if customers need strong guarantees (compliance, noisy-neighbor, per-customer keys), deploy per customer, automated via IaC. If you have many small tenants, use shared deployment with tenant-partitioned stores and per-tenant issuer and keys. In your current `Program.cs` you use in-memory stores, so either route needs you to move to EF-based configuration/operational stores first.
