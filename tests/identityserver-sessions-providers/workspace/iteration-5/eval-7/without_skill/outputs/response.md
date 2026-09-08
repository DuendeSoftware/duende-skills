# Tuning the Expired-Session Cleanup Job

Duende IdentityServer runs a background job that purges expired server-side session records from the store. You configure it through the server-side session options. For your requirements — run every 5 minutes, batches of 200, and no back-channel logout on expiry — set the following.

## Program.cs

```csharp
builder.Services.AddIdentityServer(options =>
{
    var sessions = options.ServerSideSessions;

    // enable cleanup (default true)
    sessions.RemoveExpiredSessions = true;

    // run every 5 minutes
    sessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);

    // remove 200 records per batch
    sessions.RemoveExpiredSessionsBatchSize = 200;

    // do not send back-channel logout when cleaning up expired sessions
    sessions.ExpiredSessionsTriggerBackchannelLogout = false;
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

## Randomizing the first run across instances

For a multi-instance deployment you want the instances to stagger their cleanup so they don't all hit the database at the same moment. A common approach is to offset the job start per instance — for example, delay the first run by a random amount before the recurring schedule kicks in:

```csharp
// pseudo: introduce a random startup delay per instance
var jitter = TimeSpan.FromSeconds(Random.Shared.Next(0, 300));
// apply this delay before the first cleanup pass
```

If you're running behind a load balancer, staggering the process start times (or using a leader-election/distributed-lock pattern so only one instance performs cleanup) also prevents conflicts.

## Summary

- `RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5)` → every 5 minutes.
- `RemoveExpiredSessionsBatchSize = 200` → 200 per batch.
- `ExpiredSessionsTriggerBackchannelLogout = false` → no logout notifications on expiry.
- Stagger cleanup start across instances to avoid multi-instance conflicts.
