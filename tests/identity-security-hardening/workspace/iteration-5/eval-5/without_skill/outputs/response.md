# Replacing the Developer Signing Credential with Automatic Key Management

The `AddDeveloperSigningCredential()` call is for local development only — it produces a temporary key that isn't safe or durable for production. Duende IdentityServer's automatic key management can generate, rotate, and retain keys for you, and encrypt them at rest through ASP.NET Core Data Protection.

## 1. Configure key management (remove the dev credential)

```csharp
using Microsoft.IdentityModel.Tokens;

builder.Services.AddIdentityServer(options =>
{
    // Rotate every 90 days
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);

    // Propagate a new key 14 days before it becomes the active signing key
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(14);

    // Retain the retired key for validation for 14 days after rotation
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);

    // Encrypt keys at rest with Data Protection
    options.KeyManagement.DataProtectKeys = true;

    // ES256 as the primary algorithm, RS256 as fallback
    options.KeyManagement.SigningAlgorithms = new[]
    {
        new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256), // ES256
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256)    // RS256
    };
})
// .AddDeveloperSigningCredential()  <-- removed
.AddInMemoryIdentityResources(/* ... */)
.AddInMemoryApiScopes(/* ... */)
.AddInMemoryClients(/* ... */);
```

The first algorithm in `SigningAlgorithms` is used to sign new tokens, so listing `EcdsaSha256` (ES256) before `RsaSha256` (RS256) makes ES256 primary and RS256 the fallback for older clients.

## 2. Set up Data Protection for the load-balanced deployment

Because you run multiple instances behind a load balancer, all nodes must share one Data Protection key ring, or they won't be able to decrypt each other's protected data (including the signing keys). Persist the keys to the shared path and set a stable application name:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    .SetApplicationName("identity-server");
```

## Notes

- `AddDeveloperSigningCredential()` is removed; automatic key management now owns the signing keys.
- Rotation is 90 days, with 14-day propagation and retention so a new key is published before it signs and the old key stays valid until existing tokens expire.
- `DataProtectKeys = true` encrypts the key material at rest.
- The Data Protection keys must live on durable, shared storage (e.g., a mounted volume or network share), never on ephemeral container disk — otherwise losing them makes all encrypted data unreadable.
- If you're on a licensed edition, confirm your license covers automatic key management before deploying.
