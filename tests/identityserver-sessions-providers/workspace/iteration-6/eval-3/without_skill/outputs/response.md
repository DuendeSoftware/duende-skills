# 8-hour absolute session lifetime

```csharp
builder.Services.AddIdentityServer(options =>
    {
        options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
        options.Authentication.CookieSlidingExpiration = false;

        options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
        options.Authentication.CoordinateClientLifetimesWithUserSession = true;
    })
    .AddServerSideSessions()
    ...
```

Server-side sessions (with an operational store) are required for expired sessions to trigger back-channel logout, since the server must know about the session after the cookie expires.

## web.app client

```csharp
new Client
{
    ClientId = "web.app",
    ...
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
    BackChannelLogoutSessionRequired = true,
    AccessTokenLifetime = 300,      // 5 minutes
    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
}
```

With a 5-minute access token the client refreshes frequently; with coordination enabled, refresh calls check the user session, so a refresh counts as activity. With a non-sliding cookie the session still ends at 8 hours absolute, and refresh tokens are then rejected.

## Notes
- Sliding disabled means the 8-hour clock is fixed from sign-in.
- Your client must implement a back-channel logout endpoint at that URI.
- Without `AddServerSideSessions()` the settings still apply to the cookie, but back-channel notification on expiry won't occur.
