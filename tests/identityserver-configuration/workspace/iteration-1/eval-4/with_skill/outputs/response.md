# Production Key Management Configuration

Here's the key management configuration for a load-balanced deployment:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Key rotation policy
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(60);
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(7);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(21);

    // Encrypt keys at rest via ASP.NET Data Protection
    options.KeyManagement.DataProtectKeys = true;

    // Shared key storage path for all load-balanced instances
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";
});
```

## Key Lifecycle

With these settings, keys move through four phases:

1. **Announced** (days 53-60): New key is added to the JWKS discovery document but not yet used for signing. This gives clients and APIs 7 days (`PropagationTime`) to refresh their cached JWKS and learn about the new key.

2. **Active** (days 0-60): Key is used to sign all new tokens for 60 days (`RotationInterval`).

3. **Retired** (21 days after rotation): Key is no longer used for signing, but remains in the JWKS document so APIs can still validate tokens signed with it during its `RetentionDuration`.

4. **Deleted**: Key is removed from discovery after retention period expires.

## Load Balancer Considerations

The `KeyPath` points to `/mnt/shared/identity-keys`, which must be a network-accessible path readable/writable by all IdentityServer instances. This ensures all instances use the same signing keys.

With `DataProtectKeys = true`, the key material is encrypted at rest using ASP.NET Data Protection. Make sure Data Protection is also configured with a shared key ring (e.g., via database or Redis) so all instances can decrypt the keys.

## Alternative: Database-Backed Key Storage

Instead of a shared file path, you can use the EF Core operational store for key storage, which is often simpler in containerized environments:

```csharp
idsvrBuilder.AddOperationalStore(options =>
{
    options.ConfigureDbContext = b =>
        b.UseSqlServer(connectionString);
});
```

The operational store automatically handles signing key persistence.
