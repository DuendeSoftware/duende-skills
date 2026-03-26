# Configuring Automatic Session Cleanup

Here's how to configure the expired session cleanup job with your specific requirements.

## Updated Program.cs

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Cleanup job configuration
    options.ServerSideSessions.RemoveExpiredSessions = true;
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);
    options.ServerSideSessions.RemoveExpiredSessionsBatchSize = 200;

    // Randomize the first cleanup run to avoid multi-instance conflicts
    options.ServerSideSessions.FuzzExpiredSessionRemovalStart = true;

    // Disable back-channel logout on session expiration
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = false;
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddServerSideSessions()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });
```

## Configuration Explained

| Setting | Value | Purpose |
|---|---|---|
| `RemoveExpiredSessions` | `true` | Enables the periodic cleanup job (default is `true`) |
| `RemoveExpiredSessionsFrequency` | 5 minutes | How often the cleanup runs (default is 10 minutes) |
| `RemoveExpiredSessionsBatchSize` | 200 | Records removed per batch (default is 100) |
| `FuzzExpiredSessionRemovalStart` | `true` | Randomizes the first run start time — critical for multi-instance deployments to avoid all instances running cleanup simultaneously |
| `ExpiredSessionsTriggerBackchannelLogout` | `false` | Disables back-channel logout notifications when expired sessions are cleaned up |

## Important Notes

- `FuzzExpiredSessionRemovalStart = true` is actually the default, so it would work even without explicitly setting it. Setting it explicitly improves code clarity.
- With a batch size of 200 and 5-minute interval, you can process up to 2,400 expired sessions per hour
- If your backlog is very large, consider temporarily increasing the batch size or reducing the frequency
- Monitor the cleanup job via structured logging — IdentityServer logs when batches are processed