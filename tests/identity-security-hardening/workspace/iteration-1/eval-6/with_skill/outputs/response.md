# Server-Side Sessions with Hardened Lifetimes

## Configuration

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Absolute cookie lifetime — 8 hours, no sliding
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    // Tie client token lifetimes to the user session
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;

    // Server-side session cleanup
    options.ServerSideSessions.RemoveExpiredSessions = true;
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(10);

    // Trigger back-channel logout when sessions expire
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
})
.AddInMemoryIdentityResources(/* ... */)
.AddInMemoryApiScopes(/* ... */)
.AddInMemoryClients(new List<Client>
{
    new Client
    {
        ClientId = "web.app",
        ClientName = "Main Web Application",
        AllowedGrantTypes = GrantTypes.Code,
        RequirePkce = true,
        ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:WebApp"].Sha256()) },
        RedirectUris = { "https://app.example.com/signin-oidc" },
        PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
        AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },
        AllowOfflineAccess = true,
        AccessTokenLifetime = 300,
        RefreshTokenUsage = TokenUsage.OneTimeOnly,
        CoordinateLifetimeWithUserSession = true,

        // Back-channel logout configuration
        BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
        BackChannelLogoutSessionRequired = true
    },
    // ... other clients ...
})
// Enable server-side sessions
.AddServerSideSessions();
```

## What This Achieves

- **8-hour absolute cookie lifetime** with no sliding expiration prevents indefinitely-extended sessions
- **Expired session cleanup every 10 minutes** removes stale sessions from the store
- **Back-channel logout on expiry** notifies clients when sessions end server-side
- **Coordinated client lifetimes** ensures refresh tokens can't outlive the user's session
- **`AddServerSideSessions()`** enables the server-side session store (Business/Enterprise edition)
- **`BackChannelLogoutUri`** on web.app enables server-to-server session termination notifications
