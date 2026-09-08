# Configuring an 8-Hour Absolute Session with Back-Channel Logout

You want an absolute 8-hour session (no sliding), client lifetimes coordinated with the user session, back-channel logout on expiry, and a 5-minute access token on `web.app` with a back-channel logout URI.

## Program.cs — IdentityServer options

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Absolute 8-hour session; disable sliding so it does not keep extending
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    // Tie client token lifetimes to the user session globally
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;

    // Fire back-channel logout when a session expires
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
})
    .AddInMemoryIdentityResources(/* ... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryClients(/* ... */)
    .AddServerSideSessions(); // required for session coordination and expiry logout
```

## web.app client

```csharp
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    ClientSecrets = { new Secret("WebAppSecret".Sha256()) },
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },
    AllowOfflineAccess = true,
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    AllowedCorsOrigins = { "https://app.example.com" },

    // Back-channel logout endpoint
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel",

    // 5-minute access token so refresh usage signals activity frequently
    AccessTokenLifetime = 300
}
```

## Why it works

- `CookieLifetime = 8h` with `CookieSlidingExpiration = false` gives a fixed 8-hour window that does not renew on each request.
- `CoordinateClientLifetimesWithUserSession = true` links each client's token lifetime to the user session, so when the session ends the tokens are no longer valid.
- `ExpiredSessionsTriggerBackchannelLogout = true` plus a `BackChannelLogoutUri` on the client means expired sessions push a logout notification to `https://app.example.com/bff/backchannel`.
- Because the access token lives only 300 seconds (5 minutes) — far less than the 8-hour session — an active user's client keeps refreshing, which keeps the session alive; an inactive user stops refreshing and the session lapses.

The access token lifetime (300s) is intentionally much shorter than the session lifetime (8h).
