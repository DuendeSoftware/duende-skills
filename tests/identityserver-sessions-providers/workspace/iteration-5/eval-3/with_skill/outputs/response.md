# Inactivity Timeout: 8-Hour Absolute Session, No Sliding

To get an 8-hour absolute session with back-channel logout on expiry and client lifetimes coordinated with the user session, configure three things on IdentityServer plus per-client settings on `web.app`.

## Program.cs — IdentityServer options

```csharp
builder.Services.AddIdentityServer(options =>
{
    // 8-hour absolute cookie/session lifetime, no sliding renewal
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    // Coordinate client token lifetimes with the user's server-side session (global)
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;

    // Expired sessions trigger back-channel logout
    // (defaults to true; set explicitly for clarity)
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
})
    .AddInMemoryIdentityResources(/* ... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryClients(/* ... see client changes below ... */)
    // Server-side sessions are REQUIRED for coordination + back-channel-on-expiry
    .AddServerSideSessions();
```

Why each setting:

- **`CookieLifetime = 8h` + `CookieSlidingExpiration = false`** → absolute session lifetime, never slides forward.
- **`CoordinateClientLifetimesWithUserSession = true`** → client token lifetimes are tied to the user session globally, so a session expiry cascades to the client's tokens. This is the one setting you *must* enable for inactivity coordination.
- **`ExpiredSessionsTriggerBackchannelLogout = true`** → when the session expires, clients with a `BackChannelLogoutUri` are notified.
- **`AddServerSideSessions()`** → the central session record that makes all of the above possible.

## web.app client changes

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

    // Back-channel logout endpoint (BFF)
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel",

    // 5-minute access token: short enough that refresh-token usage
    // regularly signals activity and keeps the session alive.
    AccessTokenLifetime = 300,
}
```

## The key relationship

The **access token lifetime (300s / 5 min) is much shorter than the session lifetime (8h)**. Because `CoordinateClientLifetimesWithUserSession` is on, each refresh-token exchange extends the server-side session — so an active user stays signed in, while an idle user's session lapses and triggers back-channel logout to `https://app.example.com/bff/backchannel`.
