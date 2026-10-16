Automatic key management is configured through `IdentityServerOptions.KeyManagement`.

```csharp
builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.Enabled = true;                              // default, explicit for clarity
        options.KeyManagement.RotationInterval = TimeSpan.FromDays(30);    // new key every 30 days
        options.KeyManagement.PropagationTime = TimeSpan.FromDays(5);      // announced 5 days before it becomes active
        options.KeyManagement.RetentionDuration = TimeSpan.FromDays(7);    // retired keys still published for 7 days
        options.KeyManagement.DeleteRetiredKeys = false;                   // keep retired keys in the store
    })
    .AddInMemoryClients(/* ...unchanged... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryIdentityResources(/* ... */);
```

Notes:
- `RotationInterval` must be longer than `PropagationTime + RetentionDuration` (30 > 12 here), otherwise validation fails.
- `PropagationTime` should be at least as long as client/API JWKS cache durations so consumers know the key before it signs anything.
- `DeleteRetiredKeys = false` means retired keys stay in the store but are no longer published in discovery after the retention period.
- Keys are stored on disk (`~/keys` by default) unless you add the EF operational store. For production, use `AddOperationalStore` so all instances share keys.
