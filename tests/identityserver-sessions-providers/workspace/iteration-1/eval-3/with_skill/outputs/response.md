# Configuring Inactivity Timeout

Here's how to configure IdentityServer with an 8-hour absolute session lifetime, coordinated client lifetimes, and back-channel logout on expiration.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer(options =>
{
    // 8-hour absolute session lifetime, no sliding expiration
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    // Coordinate client token lifetimes with the user session globally
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;

    // Trigger back-channel logout when expired sessions are cleaned up
    // (this is true by default, shown here for explicitness)
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
})
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
        new ApiScope("orders.manage", "Manage orders")
    })
    .AddInMemoryClients(new List<Client>
    {
        // Interactive web application — with back-channel logout and short access token lifetime
        new Client
        {
            ClientId = "web.app",
            ClientName = "Main Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,

            ClientSecrets = { new Secret("WebAppSecret".Sha256()) },

            RedirectUris = { "https://app.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
            BackChannelLogoutUri = "https://app.example.com/bff/backchannel",

            AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

            AllowOfflineAccess = true,
            AccessTokenLifetime = 300, // 5 minutes — shorter than session, so refresh usage signals activity
            RefreshTokenUsage = TokenUsage.OneTimeOnly,

            AllowedCorsOrigins = { "https://app.example.com" }
        },

        // BFF-secured SPA
        new Client
        {
            ClientId = "spa.bff",
            ClientName = "SPA with BFF",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("SpaSecret".Sha256()) },
            RedirectUris = { "https://spa.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://spa.example.com/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "catalog.read" },
            AllowOfflineAccess = true,
            AccessTokenLifetime = 300,
            RefreshTokenUsage = TokenUsage.OneTimeOnly,
            AllowedCorsOrigins = { "https://spa.example.com" }
        },

        // Machine-to-machine client
        new Client
        {
            ClientId = "background.worker",
            ClientName = "Background Worker",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("WorkerSecret".Sha256()) },
            AllowedScopes = { "orders.manage" },
            AccessTokenLifetime = 3600
        },

        // CIBA client (not yet configured)
        new Client
        {
            ClientId = "kiosk.app",
            ClientName = "Bank Kiosk Application",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("KioskSecret".Sha256()) },
            AllowedScopes = { "openid", "profile", "catalog.read" }
        }
    })
    // Enable server-side sessions — required for inactivity timeout
    .AddServerSideSessions();

// Static external providers
builder.Services.AddAuthentication()
    .AddGoogle("Google", options =>
    {
        options.ClientId = builder.Configuration["ExternalProviders:Google:ClientId"]!;
        options.ClientSecret = builder.Configuration["ExternalProviders:Google:ClientSecret"]!;
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
    })
    .AddOpenIdConnect("EntraId", "Microsoft Entra ID", options =>
    {
        options.Authority = builder.Configuration["ExternalProviders:EntraId:Authority"];
        options.ClientId = builder.Configuration["ExternalProviders:EntraId:ClientId"];
        options.ClientSecret = builder.Configuration["ExternalProviders:EntraId:ClientSecret"];
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.ResponseType = "code";
    });

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
```

## How It Works

1. **`CookieLifetime = TimeSpan.FromHours(8)`** — Sets the absolute session lifetime to 8 hours. After 8 hours, the session expires regardless of activity.

2. **`CookieSlidingExpiration = false`** — Disables sliding expiration. The session cannot be extended by activity; it has a hard 8-hour limit.

3. **`CoordinateClientLifetimesWithUserSession = true`** — Globally enables coordination between client token lifetimes and the server-side session. When a client uses refresh tokens, introspection, or userinfo, these protocol calls extend the server-side session (for inactivity tracking). When the session expires, client tokens are revoked.

4. **`ExpiredSessionsTriggerBackchannelLogout = true`** — When the session cleanup job finds expired sessions, it sends back-channel logout notifications to clients that have a `BackChannelLogoutUri`. This is the default, shown explicitly here.

5. **`BackChannelLogoutUri` on web.app** — The web.app client now has a back-channel logout URI so it receives notifications when the session expires.

6. **`AccessTokenLifetime = 300` on web.app** — 5-minute access token lifetime. This is critical: the access token must be shorter than the session lifetime so that the client is forced to use refresh tokens regularly, which signals activity to IdentityServer and keeps the session alive.

**Important**: `AddServerSideSessions()` must be called to enable server-side sessions. Without it, there's no server-side session record to track expiration and activity.
