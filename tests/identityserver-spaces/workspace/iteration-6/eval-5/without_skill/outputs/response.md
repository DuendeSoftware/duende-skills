# What multi-tenant spaces do not isolate (and your plan)

I can't verify Spaces specifics from memory, but based on how IdentityServer is built, a logical tenant layer typically isolates **configuration and issuer**, not infrastructure. Your plan shares four things, each with consequences:

1. **Signing keys (shared)**: all tenants' tokens are signed with the same key. A token from one tenant is cryptographically valid for another if only signature is checked; separation depends solely on `iss`/`aud` validation. Compromise of a key affects every tenant, and rotation is global. Prefer per-tenant keys if tenants need independence.
2. **Data Protection keys (shared)**: cookies and protected payloads (authentication cookies, state, `ConsentCookie`, etc.) can be decrypted by any tenant. Use different cookie names/paths per tenant, and a distinct Data Protection application name/purpose per tenant where possible, otherwise a cookie from one tenant could be accepted by another.
3. **Redis cache (shared)**: cache keys must be prefixed with tenant ID, or entries (discovery docs, client configs, JWKS, user profile data) can bleed across tenants. Use a key prefix per tenant or separate Redis databases.
4. **One shared user database**: users are not tenant-partitioned unless you add that. Same username in two tenants collides, and a user can log into tenants they do not belong to unless you enforce a tenant membership check in login and profile service code. Add `TenantId` to users and filter on it everywhere.

Other things not isolated: process resources (CPU, memory, noisy neighbors), logging/telemetry, deployment/upgrade lifecycle, rate limits, and the database server itself.

**Bottom line**: this plan gives you tenant-labelled behavior but weak security isolation. Treat it as acceptable only if tenants are mutually trusting (e.g. internal business units). For external customers, partition keys, cookies, cache and users per tenant, or deploy separate instances.
