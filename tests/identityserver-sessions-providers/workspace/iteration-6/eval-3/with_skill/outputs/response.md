# 8-hour absolute lifetime with coordinated client lifetimes

```csharp
builder.Services.AddIdentityServer(options =>
    {
        // Session lifetime inherited from the cookie handler: absolute 8h, no sliding
        options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
        options.Authentication.CookieSlidingExpiration = false;

        // Coordinate refresh/reference token lifetimes with the user session
        options.Authentication.CoordinateClientLifetimesWithUserSession = true;

        // Notify all clients (not only coordinated ones) when a session expires
        options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
    })
    .AddServerSideSessions()
    .AddOperationalStore(/* EF store, see connection string */);
```

Server-side sessions (Business/Enterprise) are the prerequisite: they are the central record that lets IdentityServer notice expiry and clean up.

## web.app

```csharp
new Client
{
    ClientId = "web.app",
    // ...existing settings...
    AllowOfflineAccess = true,
    AccessTokenLifetime = 300,   // 5 minutes: shorter than the session
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
    BackChannelLogoutSessionRequired = true
}
```

## How it works
- With server-side sessions, refresh token requests (and introspection/userinfo) act as activity signals that extend the session. A 5-minute access token means the client refreshes frequently, so refresh usage signals activity. **The access token lifetime must be shorter than the session timeout**, otherwise the client won't refresh in time.
- When the session expires, IdentityServer revokes tokens of coordinated clients and sends back-channel logout to them; with `ExpiredSessionsTriggerBackchannelLogout = true` other clients get it too.
- The BFF at `/bff/backchannel` must implement back-channel logout and handle refresh failure.
- If the session record is extended via activity, the effective lifetime can exceed 8 hours. If you need a hard 8-hour ceiling, also set `UserSsoLifetime = 8 * 3600` and an absolute refresh token lifetime (`RefreshTokenExpiration = TokenExpiration.Absolute`, `AbsoluteRefreshTokenLifetime = 8 * 3600`) on the client.
- Persist Data Protection keys across instances.
