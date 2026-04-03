# Configure Server-Side Sessions with Hardened Lifetimes

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// IdentityServer with server-side sessions and hardened lifetimes
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
    {
        // Absolute cookie lifetime — session cannot outlive 8 hours
        options.Authentication.CookieLifetime = TimeSpan.FromHours(8);

        // No sliding expiration — prevents indefinitely-extended sessions
        options.Authentication.CookieSlidingExpiration = false;

        // Tie client token lifetimes to the user session
        options.Authentication.CoordinateClientLifetimesWithUserSession = true;

        // Server-side session configuration
        options.ServerSideSessions.RemoveExpiredSessions = true;
        options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(10);

        // Trigger back-channel logout when sessions expire
        options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
    })
    .AddDeveloperSigningCredential()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("catalog.read", "Read access to the catalog"),
        new ApiScope("catalog.write", "Write access to the catalog"),
        new ApiScope("orders.manage", "Manage orders"),
        new ApiScope("internal-api", "Internal API access")
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web.app",
            ClientName = "Main Web Application",
            AllowedGrantTypes = GrantTypes.CodeAndClientCredentials,
            RequirePkce = false,

            ClientSecrets = { new Secret("SuperSecret123".Sha256()) },

            RedirectUris = { "https://*.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://*.example.com/signout-callback-oidc" },

            AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

            AllowOfflineAccess = true,
            AccessTokenLifetime = 28800,
            RefreshTokenUsage = TokenUsage.ReUse,
            RefreshTokenExpiration = TokenExpiration.Sliding,
            AbsoluteRefreshTokenLifetime = 2592000,

            AllowedCorsOrigins = { },

            // Back-channel logout configuration
            BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
            BackChannelLogoutSessionRequired = true,

            // Coordinate client token lifetime with user session
            CoordinateLifetimeWithUserSession = true
        },

        new Client
        {
            ClientId = "spa.legacy",
            ClientName = "Legacy SPA",
            AllowedGrantTypes = GrantTypes.Implicit,
            AllowAccessTokensViaBrowser = true,
            RedirectUris = { "https://spa.example.com/callback" },
            PostLogoutRedirectUris = { "https://spa.example.com" },
            AllowedScopes = { "openid", "profile", "catalog.read" },
            AllowedCorsOrigins = { "https://spa.example.com" }
        },

        new Client
        {
            ClientId = "background.worker",
            ClientName = "Background Processing Service",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("WorkerSecret!".Sha256()) },
            AllowedScopes = { "internal-api", "orders.manage" },
            AccessTokenLifetime = 3600
        },

        new Client
        {
            ClientId = "internal.api.consumer",
            ClientName = "Internal API Consumer",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("InternalSecret".Sha256()) },
            AllowedScopes = { "internal-api" },
            AccessTokenType = AccessTokenType.Jwt,
            AccessTokenLifetime = 3600
        },

        new Client
        {
            ClientId = "native.app",
            ClientName = "Mobile Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = false,
            RedirectUris =
            {
                "com.example.app:/callback",
                "https://app.example.com/callback"
            },
            AllowedScopes = { "openid", "profile", "catalog.read" },
            AllowOfflineAccess = true,
            RefreshTokenUsage = TokenUsage.OneTimeOnly,
            AccessTokenLifetime = 300
        }
    });

// Enable server-side sessions
idsvrBuilder.AddServerSideSessions();

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
```

## What Was Configured

### Server-Side Session Settings
| Setting | Value | Purpose |
|---------|-------|---------|
| `CookieLifetime` | 8 hours | Absolute maximum session duration |
| `CookieSlidingExpiration` | `false` | Prevents indefinitely-extended sessions — session always ends after 8 hours |
| `RemoveExpiredSessions` | `true` | Clean up expired sessions from the store |
| `RemoveExpiredSessionsFrequency` | 10 minutes | Cleanup job runs every 10 minutes |
| `ExpiredSessionsTriggerBackchannelLogout` | `true` | When a session expires server-side, IdentityServer sends back-channel logout notifications to all participating clients |
| `CoordinateClientLifetimesWithUserSession` | `true` | Client token lifetimes (refresh tokens, etc.) are tied to the user session — when the session ends, tokens are revoked |

### Server-Side Sessions Enabled
`AddServerSideSessions()` is called on the IdentityServer builder to enable server-side session storage. This is required for centralized session control and back-channel logout on session expiry.

### web.app Client Updates
- `BackChannelLogoutUri = "https://app.example.com/bff/backchannel"` — IdentityServer sends a POST to this URL when the user's session ends
- `BackChannelLogoutSessionRequired = true` — the logout token includes the session ID so the client can match it
- `CoordinateLifetimeWithUserSession = true` — this client's refresh tokens are revoked when the user session ends
