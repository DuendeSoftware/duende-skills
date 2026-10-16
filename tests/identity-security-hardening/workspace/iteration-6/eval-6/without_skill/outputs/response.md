# Server-side sessions with hardened lifetimes

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Absolute 8 hour cookie, no sliding
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    // Coordinate client token lifetimes with the session
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;

    // Server-side session housekeeping
    options.ServerSideSessions.RemoveExpiredSessions = true;
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(10);
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
})
.AddServerSideSessions()
// existing registrations...
```

With a persistent store (recommended for multiple nodes):
```csharp
.AddOperationalStore(o => { /* EF config */ })
.AddServerSideSessions();
```
The default in-memory store loses sessions on restart.

## web.app back-channel logout
```csharp
new Client
{
    ClientId = "web.app",
    ...
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
    BackChannelLogoutSessionRequired = true,
    ...
}
```

## Explanation
- `CookieLifetime` + `CookieSlidingExpiration=false` makes an absolute 8h session.
- `CoordinateClientLifetimesWithUserSession` ties refresh token and access token validity to the session, so refresh stops when the session ends/expires.
- Cleanup every 10 minutes; expired sessions trigger back-channel logout so clients (e.g. the BFF at `/bff/backchannel`) clear their local sessions.
- Make sure the client's `AccessTokenLifetime` is short (the current 8 hours should be reduced, e.g. 5 minutes) and that the client's own cookie doesn't outlive the IdentityServer session.
- Back-channel logout requires the client endpoint to be reachable from the IdentityServer server and `sid` claims to be included (`BackChannelLogoutSessionRequired`).
