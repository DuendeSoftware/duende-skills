# Production Automatic Key Management

Configure the `KeyManagement` section of `IdentityServerOptions` for your rotation policy, enable data protection for keys at rest, and point all load-balanced instances at the shared network path.

```csharp
using Duende.IdentityServer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Automatic key management is on by default — customize the rotation policy:
    options.KeyManagement.RotationInterval   = TimeSpan.FromDays(60);  // rotate every 60 days
    options.KeyManagement.PropagationTime     = TimeSpan.FromDays(7);   // announce 7 days before activation
    options.KeyManagement.RetentionDuration   = TimeSpan.FromDays(21);  // retain 21 days after retirement

    // Encrypt keys at rest via ASP.NET Core Data Protection
    options.KeyManagement.DataProtectKeys = true;

    // Shared path so every instance behind the load balancer reads/writes the same keys
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";
});

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

## Notes

- **`RotationInterval = 60 days`** — a new signing key becomes active every 60 days.
- **`PropagationTime = 7 days`** — a newly created key is *announced* (published in discovery/JWKS but not yet used for signing) for 7 days before it becomes active, giving clients and APIs time to pick it up.
- **`RetentionDuration = 21 days`** — a retired key stays in discovery for validation for 21 days after it stops signing, so tokens signed just before rotation still validate.
- **`DataProtectKeys = true`** — keys are encrypted at rest using ASP.NET Core Data Protection. In a load-balanced deployment, make sure the Data Protection system itself is configured with a **shared key ring** (e.g., shared file path or persisted keys) so all instances can decrypt the protected keys.
- **`KeyPath = "/mnt/shared/identity-keys"`** — the file-system store all instances share. Alternatively, use the EF Core operational store for database-backed key storage.

> Because `DataProtectKeys` is enabled, remember to also configure ASP.NET Data Protection with `PersistKeysToFileSystem`/`ProtectKeysWith...` (or a shared provider) across the load-balanced instances, otherwise each node would use its own data-protection key ring and fail to decrypt keys written by another node.
