# Expired-session cleanup configuration

```csharp
builder.Services.AddIdentityServer(options =>
    {
        options.ServerSideSessions.RemoveExpiredSessions = true;
        options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);
        options.ServerSideSessions.RemoveExpiredSessionsBatchSize = 200;
        options.ServerSideSessions.FuzzExpiredSessionRemovalStart = true;     // randomize first run
        options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = false;
    })
    .AddServerSideSessions()
    .AddOperationalStore(/* EF */);
```

| Option | Default | Your value |
|---|---|---|
| `RemoveExpiredSessions` | true | true |
| `RemoveExpiredSessionsFrequency` | 10 min | 5 min |
| `RemoveExpiredSessionsBatchSize` | 100 | 200 |
| `FuzzExpiredSessionRemovalStart` | true | true (explicit) |
| `ExpiredSessionsTriggerBackchannelLogout` | **false** | false |

Notes:
- `FuzzExpiredSessionRemovalStart` is already on by default; setting it keeps intent explicit for multi-instance deployments.
- `ExpiredSessionsTriggerBackchannelLogout` already defaults to `false`, but there's a caveat: clients that have a **coordinated lifetime** (`Client.CoordinateLifetimeWithUserSession` or global `Authentication.CoordinateClientLifetimesWithUserSession`) are *always* notified on expiry and have tokens revoked, regardless of this flag. Leave coordination off for clients that don't support back-channel logout.
- Server-side sessions must be enabled (the current Program.cs is cookie-only). Without the EF operational store they'd be in-memory, so add `AddOperationalStore` too.
- Make sure Data Protection keys are shared across instances.
