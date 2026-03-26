# Key Management Configuration

For production key rotation behind a load balancer:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(60);
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(7);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(21);
    options.KeyManagement.DataProtectKeys = true;
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";
});
```

This configures automatic key rotation every 60 days. New keys are announced 7 days before activation, and old keys are retained for 21 days after retirement. Keys are encrypted at rest and stored at the shared path accessible by all instances.
