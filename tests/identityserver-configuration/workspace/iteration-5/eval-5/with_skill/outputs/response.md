# Server-Side Sessions with Back-Channel Logout Coordination

Enable server-side sessions by calling `.AddServerSideSessions()` on the IdentityServer builder, then configure the cleanup and back-channel logout behavior via `options.ServerSideSessions`, and coordinate token lifetimes with the user session via `options.Authentication`.

```csharp
using Duende.IdentityServer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    // Clean up expired server-side sessions every 5 minutes
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);

    // When an expired session is removed, fire back-channel logout to its clients
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;

    // Tie client token lifetimes to the user session so refresh tokens are
    // revoked when the user's session ends
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;
})
    // Server-side sessions are ENABLED by this builder call — there is no
    // options.ServerSideSessions.Enabled flag.
    .AddServerSideSessions();

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

## Notes

- **`.AddServerSideSessions()`** is the switch that turns server-side sessions on. It's a builder method, *not* an options property — a common point of confusion. Without this call, the `options.ServerSideSessions.*` settings have no store to act on.
- **`RemoveExpiredSessionsFrequency = 5 minutes`** — background cleanup interval. (Cleanup itself is governed by `RemoveExpiredSessions`, which defaults to `true`.)
- **`ExpiredSessionsTriggerBackchannelLogout = true`** — when the cleanup job removes an expired session, IdentityServer sends back-channel logout notifications to the clients that participated in that session, so they can drop their own sessions.
- **`options.Authentication.CoordinateClientLifetimesWithUserSession = true`** — coordinates client token (including refresh token) lifetimes with the user's session, ensuring refresh tokens stop working once the session ends. This pairs naturally with server-side sessions.

> For back-channel logout to reach clients, each participating client must have a `BackChannelLogoutUri` configured.
