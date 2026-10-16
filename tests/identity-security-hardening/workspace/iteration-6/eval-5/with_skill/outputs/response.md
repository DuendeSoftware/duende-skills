# Automatic key management and Data Protection

Replace `AddDeveloperSigningCredential()` (a local `tempkey.jwk`, never for production) with automatic key management.

```csharp
using Microsoft.AspNetCore.DataProtection;
using Microsoft.IdentityModel.Tokens;
using Duende.IdentityServer.Configuration;

// Data Protection: shared, durable key ring for ALL instances
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    .ProtectKeysWithCertificate(LoadProtectionCertificate())   // encrypt the key ring at rest
    .SetApplicationName("identity-server");                    // identical on every node

builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = true;

    options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);
    options.KeyManagement.PropagationTime  = TimeSpan.FromDays(14);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);
    options.KeyManagement.DeleteRetiredKeys = true;

    // Signing keys are encrypted at rest with Data Protection
    options.KeyManagement.DataProtectKeys = true;

    // ES256 first (used to sign), RS256 as fallback for legacy clients
    options.KeyManagement.SigningAlgorithms = new[]
    {
        new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256),
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256)
    };
})
// no AddDeveloperSigningCredential()
.AddInMemoryIdentityResources(/* existing */)
.AddInMemoryApiScopes(/* existing */)
.AddInMemoryClients(/* existing */);
```
(`LoadProtectionCertificate()` is your helper that loads an X.509 cert from the store/vault.)

## Key points
- **Algorithm order**: the first algorithm is the default for signing new tokens. ES256 yields smaller tokens; RS256 stays published for compatibility. RS/PS/ES families are supported.
- **Rotation overlap**: a key is *announced* in JWKS for `PropagationTime` (14 days) before it signs, so API/client JWKS caches refresh. After rotation it's retained for `RetentionDuration` (14 days) so recently issued tokens still validate. Retention must be ≥ your longest token lifetime. (The checklist wants propagation ≥ 24h, retention ≥ token lifetime; 14 days satisfies both.)
- **Shared key storage for load balancing**: signing keys must be stored in a shared durable location so every node uses the same ones (the default file store at `KeyPath`, e.g. `/var/identity/keys`, works only if mounted shared; for multi-node production prefer the EF operational store).
- **Data Protection**: if keys sit on ephemeral container disk and are lost, persisted grants, cookies, server-side sessions and the encrypted signing keys become unreadable. Mount `/var/identity/dp-keys` on durable, shared storage with tight permissions; always set the same `SetApplicationName` on all instances. Alternatives: `PersistKeysToDbContext`, blob storage.
- **v8 licensing**: Automatic Key Management throws at startup if the license lacks the entitlement. Run lower environments with the production license so gaps surface before production.
- Each environment must have its own isolated key material; never share keys across environments.
