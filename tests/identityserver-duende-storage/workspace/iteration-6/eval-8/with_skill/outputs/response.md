**Context:** Duende Storage is a **preview** (8.1 previews) and is an opt-in alternative. EF Core stays fully supported. There is **no automated or in-place migration** and the schemas differ, so this is an export/import project. Think hard about whether production should run a preview, and keep a rollback path.

## Plan
**0. Rehearse** the whole thing on a production-like copy.

**1. Prepare the new storage**
- Back up the EF database.
- Deploy the Duende schema to a *separate* connection string/schema, as a controlled pipeline step (`duende storage migrate --dry-run`, then for real; Oracle uses `BuildMigrationScript` plus a DBA). The runtime identity doesn't need DDL.
- Plan whether to use separate instances for configuration and operational data.

**2. Configuration (clients, scopes, resources, IdPs)**
- Export via the EF contexts, import **through the admin APIs** (`IApiScopeAdmin`, `IIdentityResourceAdmin`, `IApiResourceAdmin`, `IClientAdmin`, `IIdentityProviderAdmin`), **never by writing rows directly** (validation, relationships, secret handling, concurrency).
- Create scopes and identity resources before the resources and clients that reference them.
- Compare counts and spot-check.
- Stop config writes, run a final import, then switch to `AddStorage` + `AddConfigurationStorage()`.

**3. Secrets**
- EF stores client/API secrets as **one-way hashes**, while admin APIs take **plaintext**. Don't import hashes as plaintext, since that would create a secret equal to the hash. Re-provision from a secure source (vault) or **rotate** with the client owners.
- Dynamic IdP secrets (`ClientSecret`) are recoverable values and stored unhashed and unencrypted in Duende Storage, so transfer them only through a protected process, and use encrypted connections and encryption at rest.

**4. Operational data (grants, codes, reference/refresh tokens, sessions, PAR, signing keys, SAML state)**
- No supported transfer tool, and you shouldn't copy rows directly.
- Lowest-risk: a **controlled reset in a maintenance window**. Users and clients re-authenticate, and reference tokens, refresh tokens, device flows and server-side sessions stop working. Communicate this.
- **JWT access tokens stay valid** if issuer, audience and signing keys remain continuous. Plan signing key rollover separately, and don't remove old validation keys until tokens signed with them expire.

**5. Cutover**
```csharp
builder.Services.AddIdentityServer()
    .AddStorage(s => s.AddPostgreSql(...))
    .AddConfigurationStorage()
    .AddOperationalStorage()
    .AddServerSideSessions();
```
- Verify discovery, JWKS, and each flow (code, client credentials, refresh, device if used) before reopening traffic.
- Remember `AddStorage` alone stores nothing.

**6. Afterwards**
- Keep the EF DB **read-only** after the final export, retain the backup and a rollback window.
- **Don't dual-write.**
- Check the purge defaults (hourly, batch 100) fit your volume.
- Protect admin services behind authn/authz/audit.
