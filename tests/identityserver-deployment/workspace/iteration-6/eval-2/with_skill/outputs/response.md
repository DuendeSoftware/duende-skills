# CryptographicException on 3 replicas

**Cause:** ASP.NET Core Data Protection keys are per-instance by default (local file system/ephemeral in a container). Pod A encrypts a cookie, state parameter, or persisted grant payload; pod B has a different key ring and throws `CryptographicException` ("The key {id} was not found in the key ring"). Restarts lose keys too. Data Protection is a cross-cutting concern for *all* Duende SDKs (IdentityServer, BFF, …) — see the general docs: <https://docs.duendesoftware.com/general/data-protection/>.

IdentityServer relies on it for: signing keys at rest (automatic key management), persisted grants, server-side sessions, external OIDC state, UI message payloads, auth cookies, and anti-forgery tokens.

## Fix

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionKeysContext>()   // or Redis / Blob / AWS SSM
    .ProtectKeysWithCertificate(cert)                      // or ProtectKeysWithAzureKeyVault
    .SetApplicationName("My.IdentityServer");
```

Rules:
1. Always persist keys to **durable** storage (if Redis, enable RDB/AOF persistence).
2. **Share** the same store across all replicas.
3. Set an **explicit, identical application name** to avoid key isolation.
4. Protect keys at rest (certificate/Key Vault).
5. Consider a key escrow sink (`IXmlEncryptor`-based) for backup.
6. Don't bake dev `~/keys` into the image.

## Also share the rest for multi-instance
- **Signing keys** (different from DP keys): use the EF operational store (`ISigningKeyStore`) — the default file-system store is per pod.
- Operational data (grants, sessions) in a shared DB, not in-memory stores.
- Distributed cache (e.g. Redis) for OIDC state data formatter, JWT replay cache, device flow throttling, PAR.
- ForwardedHeaders configured if behind an ingress.

Note: the current Program.cs uses only in-memory stores; add `AddOperationalStore` (the EF package is already referenced) so state is shared.

| Symptom | Cause |
|---|---|
| key not found in key ring | no shared keys |
| "Error unprotecting key with kid" | signing-key payload encrypted with a missing DP key |
| Works after restart only | ephemeral keys |
