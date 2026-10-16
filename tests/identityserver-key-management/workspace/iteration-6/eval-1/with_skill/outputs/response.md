```csharp
builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.Enabled = true;                            // default
        options.KeyManagement.RotationInterval = TimeSpan.FromDays(30);  // rotate every 30 days
        options.KeyManagement.PropagationTime = TimeSpan.FromDays(5);    // announced 5 days before signing
        options.KeyManagement.RetentionDuration = TimeSpan.FromDays(7);  // retired keys stay in discovery 7 days
        options.KeyManagement.DeleteRetiredKeys = false;                 // never delete retired keys
    })
    .AddInMemoryClients(/* unchanged */)
    .AddInMemoryApiScopes(/* unchanged */)
    .AddInMemoryIdentityResources(/* unchanged */);
```

Lifecycle with these values: **Announced** (5 days in discovery, not signing) → **Signing** (25 days = RotationInterval − PropagationTime) → **Retired** (7 days, discovery for validation only) → Deleted phase (no longer published; the row is kept because `DeleteRetiredKeys = false`).

Notes:
- `PropagationTime` should exceed the longest JWKS cache time of your clients/APIs (default 24h cache), so 5 days is comfortable.
- Automatic key management requires the appropriate license edition; in v8 a missing entitlement throws at startup.
- Keys default to `{ContentRootPath}/keys`, encrypted at rest with Data Protection. For multiple instances, use the EF operational store (`AddOperationalStore`) and shared Data Protection key persistence with `SetApplicationName`.
