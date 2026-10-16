# Session cleanup configuration

```csharp
builder.Services.AddIdentityServer(options =>
    {
        options.ServerSideSessions.RemoveExpiredSessions = true;
        options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);
        options.ServerSideSessions.RemoveExpiredSessionsBatchSize = 200;
        options.ServerSideSessions.FuzzExpiredSessionRemovalStart = true;
        options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = false;
    })
    .AddOperationalStore(...)
    .AddServerSideSessions();
```

- `RemoveExpiredSessionsFrequency` – interval between cleanup runs (default 10 minutes).
- `RemoveExpiredSessionsBatchSize` – rows removed per batch (default 100).
- `FuzzExpiredSessionRemovalStart` – randomizes the first run so multiple instances don't all start together (default true).
- `ExpiredSessionsTriggerBackchannelLogout` – set to false to skip notifications when a session expires.

All of this requires server-side sessions to be enabled (`AddServerSideSessions()`), which the current Program.cs lacks.
