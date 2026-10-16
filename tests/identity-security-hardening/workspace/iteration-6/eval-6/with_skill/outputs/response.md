# Server-side sessions with hardened lifetimes

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // Server-side sessions are enabled by AddServerSideSessions() below (no Enabled flag)
    options.ServerSideSessions.RemoveExpiredSessions = true;
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(10);

    // Notify clients (back-channel logout) when a session expires server-side
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;

    // Tie client token lifetimes (refresh tokens) to the user session
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;

    // Absolute 8h cookie, no sliding
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;
});

// Enable server-side sessions (requires Business/Enterprise license entitlement)
idsvrBuilder.AddServerSideSessions();
```

## `web.app` back-channel logout and token coordination
```csharp
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    // Server-to-server logout notification
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
    BackChannelLogoutSessionRequired = true,   // include sid so the right session is ended

    // Refresh tokens die with the user's session
    CoordinateLifetimeWithUserSession = true,

    // Keep access tokens short so they can't outlive the session meaningfully
    AccessTokenLifetime = 300,
    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    RefreshTokenExpiration = TokenExpiration.Absolute,
    AbsoluteRefreshTokenLifetime = 28800   // no longer than the 8h session
    // ... existing secrets, redirect URIs, scopes
}
```

## How the pieces fit
- `CookieLifetime = 8h` + `CookieSlidingExpiration = false` → a hard cap: users must re-authenticate after 8 hours regardless of activity.
- Server-side sessions store the session in the server, enabling centralized expiry, cleanup, and revocation. The cleanup job runs every 10 minutes and removes expired sessions.
- `ExpiredSessionsTriggerBackchannelLogout` makes the cleanup job call each client's `BackChannelLogoutUri`, so the BFF at `/bff/backchannel` can drop its own session; otherwise clients could keep a local session after the IdP session expired.
- `CoordinateClientLifetimesWithUserSession` (global) and the client-level `CoordinateLifetimeWithUserSession` make refresh tokens invalid once the user session ends, so refresh can't extend access past the session.

## Checks
- The `BackChannelLogoutUri` must be reachable from the IdentityServer host and use HTTPS.
- The default session store is in-memory; use a persistent shared store (EF operational store) in load-balanced deployments.
- The existing 8h `AccessTokenLifetime` should be reduced (5 min above) and `ReUse` refresh tokens changed to `OneTimeOnly`.
