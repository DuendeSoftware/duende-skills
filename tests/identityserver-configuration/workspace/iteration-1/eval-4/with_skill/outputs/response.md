Here's how to configure automatic key management for a load-balanced production deployment with your specified rotation policy and shared key storage:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;

    // Key management configuration for load-balanced deployment
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(60);     // New key every 60 days
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(7);       // Announce new key 7 days before activation
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(21);    // Keep retired keys 21 days for validation
    options.KeyManagement.DataProtectKeys = true;                       // Encrypt keys at rest via Data Protection

    // Shared file path for all load-balanced instances
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";
});

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

### Key Lifecycle with These Settings

Keys move through four phases:

1. **Announced** (Day 0–7) — The new key is published in the JWKS discovery document but not yet used for signing. This gives API consumers 7 days (`PropagationTime`) to refresh their cached keys.
2. **Active** (Day 7–67) — The key is used to sign all new tokens for 60 days (`RotationInterval`).
3. **Retired** (Day 67–88) — A new key takes over signing. The retired key remains in discovery for 21 days (`RetentionDuration`) so tokens signed with it can still be validated.
4. **Deleted** — The key is removed from discovery after retention expires (if `DeleteRetiredKeys` is true, which defaults to true).

### Important Notes

- **`DataProtectKeys = true`** encrypts signing keys at rest using ASP.NET Core Data Protection. Make sure Data Protection is also configured for shared storage across your load-balanced instances (e.g., with a shared file system or database-backed key ring).
- **`KeyPath`** points to the shared network path `/mnt/shared/identity-keys`. All instances read and write keys from this location, ensuring consistent signing across the cluster.
- **Automatic key management is enabled by default** — no need to set `options.KeyManagement.Enabled = true`.
