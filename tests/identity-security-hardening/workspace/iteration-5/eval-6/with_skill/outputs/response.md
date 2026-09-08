# Hardened Server-Side Sessions + Back-Channel Logout

Configure server-side sessions with an absolute (non-sliding) lifetime, periodic cleanup that triggers back-channel logout, and client token lifetimes coordinated with the user session. Then wire `web.app` up for back-channel logout.

## 1. Session options in `AddIdentityServer`

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    // --- Cookie / authentication lifetimes ---
    // Absolute 8-hour cookie lifetime — the session cannot outlive this
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);

    // No sliding expiration — prevents indefinitely-extended sessions
    options.Authentication.CookieSlidingExpiration = false;

    // Tie client token lifetimes to the user session
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;

    // --- Server-side session cleanup ---
    options.ServerSideSessions.RemoveExpiredSessions = true;
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(10);

    // Trigger back-channel logout when a session expires server-side
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
})
.AddInMemoryIdentityResources(/* ... */)
.AddInMemoryApiScopes(/* ... */)
.AddInMemoryClients(/* ... */);

// Enable the server-side session store — call on the builder
idsvrBuilder.AddServerSideSessions();
```

> Server-side sessions are enabled by calling `AddServerSideSessions()` on the IdentityServer builder — there is **no** `Enabled` property in options. The `options.ServerSideSessions.*` settings only take effect once the store is registered.

## 2. Configure `web.app` for back-channel logout

```csharp
new Client
{
    ClientId = "web.app",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,

    // ✅ Server-to-server logout notification (preferred over front-channel)
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
    BackChannelLogoutSessionRequired = true,

    // Coordinate this client's token lifetime with the user session too
    CoordinateLifetimeWithUserSession = true,

    // ... redirect URIs, scopes, etc ...
}
```

## How the pieces work together

- **`CookieLifetime = 8h` + `CookieSlidingExpiration = false`** — a hard 8-hour ceiling on the authentication session; it will not slide forward on activity, so a stolen cookie has a bounded life.
- **`RemoveExpiredSessions` every 10 min + `ExpiredSessionsTriggerBackchannelLogout = true`** — the cleanup job doesn't just delete expired server-side sessions, it fires back-channel logout so every client with a `BackChannelLogoutUri` is told to terminate its local session.
- **`CoordinateClientLifetimesWithUserSession` (server) + `CoordinateLifetimeWithUserSession` (client)** — when the user session ends, the client's issued tokens (including refresh tokens) are invalidated rather than living on independently.
- **`BackChannelLogoutUri = https://app.example.com/bff/backchannel`** — the server-to-server endpoint IdentityServer POSTs a logout token to; `BackChannelLogoutSessionRequired = true` includes the `sid` so the client logs out the exact session.

> Server-side sessions require the Business/Enterprise edition and (on v8) will throw at startup if the license lacks the entitlement — validate this in a lower environment first.
