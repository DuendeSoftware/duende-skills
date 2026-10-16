```csharp
builder.Services.AddIdentityServer(options =>
{
    options.ServerSideSessions.RemoveExpiredSessions = true;
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
})
.AddServerSideSessions()
.AddInMemoryClients(...);
```
To revoke refresh tokens when the session ends, set `CoordinateLifetimeWithUserSession = true` on the clients:
```csharp
new Client { ClientId = "web", CoordinateLifetimeWithUserSession = true, AllowOfflineAccess = true, ... }
```
Server-side sessions need a persistent store (Entity Framework operational store) in production. Clients need a `BackChannelLogoutUri` for the notifications.
