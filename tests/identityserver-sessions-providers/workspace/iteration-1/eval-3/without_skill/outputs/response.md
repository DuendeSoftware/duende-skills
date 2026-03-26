# Configuring Session Timeout in IdentityServer

Here's how to set up an 8-hour session with back-channel logout support.

## Updated Configuration

```csharp
builder.Services.AddIdentityServer(options =>
{
    // 8-hour session lifetime
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;
})
    // ... existing identity resources, scopes, clients ...
    .AddServerSideSessions();

// Update the web.app client
var webApp = new Client
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
    AccessTokenLifetime = 300,
    BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
    AllowedCorsOrigins = { "https://app.example.com" }
};
```

## Key Settings

- `CookieLifetime = 8 hours` — absolute session duration
- `CookieSlidingExpiration = false` — prevents session extension
- `AccessTokenLifetime = 300` — 5-minute tokens force frequent refresh
- `BackChannelLogoutUri` — enables back-channel logout notifications

## Notes

- Enable server-side sessions for session tracking
- Short access token lifetimes drive refresh token usage which can signal activity
- Back-channel logout ensures clients are notified when sessions end