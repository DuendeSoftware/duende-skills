# Automatic Key Management with ES256 + Data Protection

Replace the development signing credential with IdentityServer's automatic key management (rotation, propagation, retention, encryption at rest) and back it with a durable, shared Data Protection store for the load-balanced deployment.

## 1. Remove the developer credential; configure key management

In `AddIdentityServer(options => ...)`, remove `.AddDeveloperSigningCredential()` and configure `KeyManagement`:

```csharp
using Microsoft.IdentityModel.Tokens; // SecurityAlgorithms
using Duende.IdentityServer.Configuration; // SigningAlgorithmOptions

builder.Services.AddIdentityServer(options =>
{
    // Rotate signing keys every 90 days
    options.KeyManagement.RotationInterval   = TimeSpan.FromDays(90);

    // Announce/propagate new keys 14 days before they become active,
    // so JWKS caches on downstream APIs refresh before the key signs tokens
    options.KeyManagement.PropagationTime     = TimeSpan.FromDays(14);

    // Keep retired keys as validation keys for 14 days after rotation
    options.KeyManagement.RetentionDuration   = TimeSpan.FromDays(14);

    options.KeyManagement.DeleteRetiredKeys    = true;

    // Encrypt key material at rest via ASP.NET Core Data Protection
    options.KeyManagement.DataProtectKeys      = true;

    // Shared, durable location for all load-balanced instances
    options.KeyManagement.KeyPath              = "/var/identity/keys";

    // ✅ ES256 first = primary algorithm for new tokens; RS256 as fallback
    options.KeyManagement.SigningAlgorithms = new[]
    {
        new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256), // ES256 (primary)
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256)    // RS256 (fallback)
        {
            UseX509Certificate = true
        }
    };
})
// NOTE: no more .AddDeveloperSigningCredential()
.AddInMemoryIdentityResources(/* ... */)
.AddInMemoryApiScopes(/* ... */)
.AddInMemoryClients(/* ... */);
```

Placing `EcdsaSha256` first makes ES256 the default algorithm used to sign new tokens, while `RsaSha256` (RS256) remains available for clients/APIs that cannot yet validate ES256.

## 2. Data Protection for the load-balanced deployment

Automatic key management encrypts the signing keys at rest with Data Protection, so Data Protection itself must use durable, shared storage with a stable application name — otherwise each instance generates its own DP keys and cannot decrypt the others' material:

```csharp
builder.Services.AddDataProtection()
    // Shared path reachable by every instance (mounted volume / network share)
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    // Stable application name so all instances form one DP ring
    .SetApplicationName("identity-server");
```

## Why each piece matters

- **No `AddDeveloperSigningCredential()`** — the dev credential generates an ephemeral key (or a file checked into source), unsuitable and unsafe for production; it's replaced entirely by managed keys.
- **90-day rotation / 14-day propagation & retention** — the propagation window lets JWKS consumers cache the new public key *before* it signs; the retention window keeps the retired public key available until in-flight tokens expire. This overlap is what makes rotation non-breaking.
- **`DataProtectKeys = true`** — encrypts stored signing keys at rest.
- **Data Protection with `PersistKeysToFileSystem` + `SetApplicationName`** — required in a load-balanced deployment so all nodes share one key ring and can decrypt each other's protected key material.

> **Warning:** `/var/identity/dp-keys` and `/var/identity/keys` must be on durable, shared storage — never on ephemeral container-local disk. If Data Protection keys are lost, all encrypted signing keys, persisted grants, and cookies become unreadable.

> **v8 note:** On IdentityServer v8, Automatic Key Management throws at startup if a license is present but lacks the entitlement. Run lower environments with the production license key so entitlement gaps surface before production.
