Here's the `Program.cs` configured with automatic key management for a production load-balanced deployment:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Key management configuration for production
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(60);
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(7);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(21);
    options.KeyManagement.DataProtectKeys = true;

    // Shared key storage path for load-balanced instances
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";
});

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

**Key lifecycle with these settings:**

1. **Announced** — A new key is created and added to the JWKS discovery document 7 days before it becomes active (`PropagationTime = 7 days`). This gives downstream APIs time to refresh their JWKS cache.
2. **Active** — The key is used for signing new tokens for 60 days (`RotationInterval = 60 days`).
3. **Retired** — After rotation, the old key remains in discovery for 21 days (`RetentionDuration = 21 days`) so existing tokens can still be validated.
4. **Deleted** — After retention, keys are removed (controlled by `DeleteRetiredKeys`, which defaults to `true`).

**Load balancer considerations:**

- `KeyPath = "/mnt/shared/identity-keys"` ensures all instances in the load-balanced deployment read and write keys from the same shared file system location.
- `DataProtectKeys = true` encrypts keys at rest using ASP.NET Core Data Protection. Make sure your Data Protection keys are also persisted and shared across instances.
- Alternatively, you can use the EF Core operational store for database-backed key storage (via `AddOperationalStore()`).
