Here's how to configure key management for your load-balanced IdentityServer deployment:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Key rotation settings
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(60);
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(7);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(21);
    options.KeyManagement.DataProtectKeys = true;
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";
});

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

This configures:
- **Rotation every 60 days** — new signing keys are created on this interval
- **7-day propagation** — new keys are announced before becoming active, giving APIs time to fetch the updated JWKS
- **21-day retention** — retired keys remain available for token validation
- **Data protection** — keys are encrypted at rest
- **Shared key path** — all instances behind the load balancer use the same key store at `/mnt/shared/identity-keys`

Make sure the shared network path is accessible from all instances and that ASP.NET Core Data Protection is also configured with a shared key ring.
