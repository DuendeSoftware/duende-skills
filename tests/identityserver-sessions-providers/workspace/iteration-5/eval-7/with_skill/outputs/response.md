# Automatic Expired-Session Cleanup

Expired server-side session records are removed by a background cleanup job. Configure it on `options.ServerSideSessions`. For your requirements — every 5 minutes, batches of 200, randomized first run for multi-instance safety, and **no** back-channel logout on expiry — set:

## Program.cs

```csharp
builder.Services.AddIdentityServer(options =>
{
    var sss = options.ServerSideSessions;

    // Cleanup must be enabled (this is the default, shown for clarity)
    sss.RemoveExpiredSessions = true;

    // Run the cleanup job every 5 minutes
    sss.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);

    // Remove up to 200 expired records per batch
    sss.RemoveExpiredSessionsBatchSize = 200;

    // Randomize the FIRST cleanup run so multiple instances don't collide.
    // (Defaults to true; set explicitly to be safe.)
    sss.FuzzExpiredSessionRemovalStart = true;

    // Do NOT send back-channel logout when expired sessions are cleaned up
    sss.ExpiredSessionsTriggerBackchannelLogout = false;
})
    .AddInMemoryIdentityResources(/* ... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryClients(/* ... */)
    .AddServerSideSessions()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = db =>
            db.UseSqlServer(builder.Configuration.GetConnectionString("IdentityServer"));
    });
```

## What each option does

| Option | Value | Effect |
| --- | --- | --- |
| `RemoveExpiredSessions` | `true` | Enables the periodic cleanup job |
| `RemoveExpiredSessionsFrequency` | `TimeSpan.FromMinutes(5)` | Runs the job every 5 minutes |
| `RemoveExpiredSessionsBatchSize` | `200` | Deletes up to 200 records per pass |
| `FuzzExpiredSessionRemovalStart` | `true` | Randomizes the first run so multiple instances stagger — avoids conflicts in your multi-instance deployment |
| `ExpiredSessionsTriggerBackchannelLogout` | `false` | Suppresses back-channel logout on expiry (your clients don't support it) |

## Notes

- **Multi-instance**: `FuzzExpiredSessionRemovalStart = true` is exactly the setting for your scenario — without it, every instance would kick off its first cleanup at the same moment and contend on the same rows.
- **Back-channel logout disabled**: `ExpiredSessionsTriggerBackchannelLogout = false` means expired sessions are silently purged; clients are not notified. This overrides the default (`true`).
- `AddServerSideSessions()` plus the durable EF Core operational store is required for the cleanup job to have a store to clean.
