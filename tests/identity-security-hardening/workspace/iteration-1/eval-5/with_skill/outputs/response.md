# Replacing Developer Signing Credential with Automatic Key Management

## Problem

`AddDeveloperSigningCredential()` generates an ephemeral RSA key stored in a local file (`tempkey.jwk`). This is unsuitable for production:
- The key is not rotated
- It's not protected at rest
- It's lost on container restart
- It can't be shared across multiple instances

## Solution: Automatic Key Management with ES256 + RS256

### Remove Developer Signing Credential

Delete the `.AddDeveloperSigningCredential()` call and configure automatic key management:

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Key rotation every 90 days
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);

    // Announce new key 14 days before activation for JWKS cache refresh
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(14);

    // Keep retired keys 14 days for in-flight token validation
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);

    // Delete keys when retention period ends
    options.KeyManagement.DeleteRetiredKeys = true;

    // Encrypt signing keys at rest via ASP.NET Data Protection
    options.KeyManagement.DataProtectKeys = true;

    // ES256 as primary (smaller tokens, faster signing)
    // RS256 as fallback for legacy client compatibility
    options.KeyManagement.SigningAlgorithms = new[]
    {
        new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256),
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256)
        {
            UseX509Certificate = true
        }
    };
})
.AddInMemoryIdentityResources(/* ... */)
.AddInMemoryApiScopes(/* ... */)
.AddInMemoryClients(/* ... */);
// NO .AddDeveloperSigningCredential()
```

### Configure Data Protection for Load-Balanced Deployment

Automatic key management encrypts signing keys using ASP.NET Core Data Protection. For multiple instances, Data Protection keys must be persisted to a shared location:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    .SetApplicationName("identity-server");
```

### Complete Updated Program.cs Snippet

```csharp
using Microsoft.AspNetCore.DataProtection;
using Microsoft.IdentityModel.Tokens;

// Data Protection — shared key storage for load-balanced deployment
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    .SetApplicationName("identity-server");

// IdentityServer with automatic key management
builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(14);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);
    options.KeyManagement.DeleteRetiredKeys = true;
    options.KeyManagement.DataProtectKeys = true;

    options.KeyManagement.SigningAlgorithms = new[]
    {
        new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256),
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256)
        {
            UseX509Certificate = true
        }
    };
})
// ... resource and client registrations
// NO .AddDeveloperSigningCredential()
```

## Why ES256 First?

- **Smaller tokens**: ECDSA signatures are ~64 bytes vs ~256 bytes for RSA
- **Faster signing**: ES256 is computationally cheaper than RS256
- **Modern standard**: FAPI 2.0 and newer profiles prefer EC algorithms
- **RS256 fallback**: Legacy clients that don't support ES256 will still work with the RS256 key
