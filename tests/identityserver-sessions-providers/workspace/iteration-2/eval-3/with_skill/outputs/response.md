# Configuring Inactivity Timeout with Server-Side Sessions

Here's the updated `Program.cs` with inactivity timeout configuration, server-side sessions, and the web.app client updated for back-channel logout:

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
    // This is true by default, but shown explicitly for clarity
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
})
    .AddServerSideSessions()
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
        // Interactive web application — updated with back-channel logout and short access token
        new Client
        {
            ClientId = "web.app",
            ClientName = "Main Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,

            ClientSecrets = { new Secret("WebAppSecret".Sha256()) },

            RedirectUris = { "https://app.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

            // Back-channel logout URI for session coordination
            BackChannelLogoutUri = "https://app.example.com/bff/backchannel",

            AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

            AllowOfflineAccess = true,
            // 5-minute access token lifetime — shorter than the 8-hour session
            // so refresh token usage signals activity to keep the session alive
            AccessTokenLifetime = 300,
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

        // Kiosk client
        new Client
        {
            ClientId = "kiosk.app",
            ClientName = "Bank Kiosk Application",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("KioskSecret".Sha256()) },
            AllowedScopes = { "openid", "profile", "catalog.read" }
        }
    });

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

## How Inactivity Timeout Works

1. **`CookieLifetime = 8 hours`** sets the absolute session duration. With `CookieSlidingExpiration = false`, the session will expire exactly 8 hours after creation regardless of activity.

2. **`CoordinateClientLifetimesWithUserSession = true`** enables the key mechanism: as clients use refresh tokens, introspection, or userinfo endpoints, these protocol calls extend the server-side session. When no activity occurs within the session timeout, the session expires.

3. **`ExpiredSessionsTriggerBackchannelLogout = true`** ensures that when the session cleanup job finds an expired session, it sends back-channel logout notifications to all clients with a `BackChannelLogoutUri`.

4. **`AccessTokenLifetime = 300` (5 minutes)** on web.app is critical — it's much shorter than the 8-hour session, so the client must frequently use its refresh token. Each refresh token request signals activity to IdentityServer, keeping the session alive. If the user walks away, refresh requests stop, and the session eventually expires.
