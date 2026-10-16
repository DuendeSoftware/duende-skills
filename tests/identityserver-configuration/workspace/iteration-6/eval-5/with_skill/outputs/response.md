```csharp
builder.Services.AddIdentityServer(options =>
{
    options.ServerSideSessions.RemoveExpiredSessions = true;
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;

    // Revoke refresh tokens etc. when the user's session ends
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;
})
    .AddServerSideSessions()   // this enables the feature; there's no "Enabled" option
    .AddInMemoryClients(Config.Clients);
```
- Server-side sessions are enabled via `.AddServerSideSessions()` on the builder, not an option.
- Cleanup runs every 5 minutes (default 10).
- `ExpiredSessionsTriggerBackchannelLogout = true` notifies all clients of an expired session (clients need a `BackChannelLogoutUri`; those with coordinated lifetime are always notified).
- `CoordinateClientLifetimesWithUserSession = true` (global) ties client token lifetimes to the session; individually, `Client.CoordinateLifetimeWithUserSession` does it per-client. Refresh tokens are then revoked when the session ends.
- Use the EF Core operational store (`identityserver-stores`) for a persistent, shared session store in production.
