# Configuring Session Cleanup

Here's how to configure the automatic session cleanup job for your multi-instance deployment.

## Updated Program.cs

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Session cleanup configuration
    options.ServerSideSessions.RemoveExpiredSessions = true;
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);
    options.ServerSideSessions.RemoveExpiredSessionsBatchSize = 200;

    // Randomize the first cleanup run to avoid conflicts in multi-instance deployment
    options.ServerSideSessions.FuzzExpiredSessionRemovalStart = true;

    // Disable back-channel logout on session expiration since clients don't support it
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = false;
})
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("catalog.read", "Read access to the catalog"),
        new ApiScope("catalog.write", "Write access to the catalog"),
        new ApiScope("orders.manage", "Manage orders")
    })
    .AddInMemoryClients(new List<Client>
    {
        // ... existing clients ...
    })
    // Enable server-side sessions
    .AddServerSideSessions();
```

## Configuration Explained

| Option | Value | Purpose |
|--------|-------|---------|
| `RemoveExpiredSessions` | `true` | Enables periodic cleanup of expired sessions (this is the default) |
| `RemoveExpiredSessionsFrequency` | `TimeSpan.FromMinutes(5)` | Cleanup job runs every 5 minutes (default is 10 minutes) |
| `RemoveExpiredSessionsBatchSize` | `200` | Removes up to 200 expired records per batch (default is 100) |
| `FuzzExpiredSessionRemovalStart` | `true` | Randomizes the first cleanup run start time. This is critical for multi-instance deployments to avoid all instances trying to clean up at the same time (this is the default) |
| `ExpiredSessionsTriggerBackchannelLogout` | `false` | Disables back-channel logout notifications when expired sessions are cleaned up. Since your clients don't support back-channel logout, there's no point in sending these notifications (default is `true`) |

**Note**: `AddServerSideSessions()` must be called to enable server-side sessions. Without it, there's no session store for the cleanup job to operate on.
