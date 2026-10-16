# Automatic key management + Data Protection

```csharp
using Microsoft.AspNetCore.DataProtection;
using Duende.IdentityServer.Models;

builder.Services.AddDataProtection()
    .SetApplicationName("IdentityServer")
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"));
    // In production also protect keys at rest, e.g. .ProtectKeysWithCertificate(...) / Key Vault

builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = true;
    options.KeyManagement.SigningAlgorithms = new[]
    {
        new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256),               // ES256 primary
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256) { UseX509Certificate = false } // RS256 fallback
    };
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(14);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);
    options.KeyManagement.DeleteRetiredKeys = true;
})
// remove .AddDeveloperSigningCredential()
.AddInMemoryIdentityResources(...)
```
(`using Microsoft.IdentityModel.Tokens;` for `SecurityAlgorithms`.)

## Notes
- Remove `AddDeveloperSigningCredential()`; it writes `tempkey.jwk` locally and isn't suitable for production.
- Automatic key management stores keys in the operational store (EF `ISigningKeyStore`); with multiple instances you **must** use a shared store (e.g. `AddOperationalStore`), otherwise each node generates its own keys. The default file-based store is only for single-node.
- Automatic key management encrypts keys using Data Protection, so all nodes need the **same Data Protection keys and application name**: shared persistent key ring (`/var/identity/dp-keys` must be a shared volume mounted on all nodes) and ideally encryption at rest. Without it, nodes can't decrypt each other's signing keys.
- Set file permissions on the dp-keys directory to the service account only.
- Propagation time = how long a new key is published in discovery before use, so caches in APIs pick it up; retention = how long retired keys remain published so previously issued tokens still validate. Both should exceed the maximum JWKS cache duration of clients and the longest token lifetime.
- The first algorithm in the list is used for signing; the others are published for compatibility.
