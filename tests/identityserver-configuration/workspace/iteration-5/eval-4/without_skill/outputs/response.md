# Production Automatic Key Management Behind a Load Balancer

Duende IdentityServer's automatic key management handles signing key creation and rotation. You configure it through `IdentityServerOptions.KeyManagement`.

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Rotate to a new signing key every 60 days
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(60);

    // Announce (publish) the new key 7 days before it becomes active for signing
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(7);

    // Keep retired keys available for validation for 21 days after retirement
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(21);

    // Protect keys at rest with ASP.NET Core Data Protection
    options.KeyManagement.DataProtectKeys = true;

    // Shared storage path so all load-balanced instances use the same keys
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";
});

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

## Explanation

- **RotationInterval** controls how often a fresh signing key becomes active (60 days).
- **PropagationTime** is the lead time a key is published before it's used for signing (7 days), so downstream clients refresh their JWKS cache first.
- **RetentionDuration** keeps old keys in the published JWKS for validation after they stop signing (21 days).
- **DataProtectKeys = true** encrypts the stored keys via Data Protection. In a load-balanced setup you should also configure Data Protection to persist its own keys to a shared location, otherwise nodes can't decrypt each other's keys.
- **KeyPath** points every instance to the same shared network path `/mnt/shared/identity-keys`. A database-backed operational store is another option for multi-instance deployments.
