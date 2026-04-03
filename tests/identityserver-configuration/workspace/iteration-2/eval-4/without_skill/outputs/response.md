Here's how to configure key management for a load-balanced IdentityServer deployment:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(60);
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(7);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(21);
    options.KeyManagement.DataProtectKeys = true;
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";
});

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

This configures the signing key to rotate every 60 days, with a 7-day propagation window and 21-day retention. Keys are encrypted at rest using Data Protection. The shared path ensures all instances behind the load balancer can access the same keys.
