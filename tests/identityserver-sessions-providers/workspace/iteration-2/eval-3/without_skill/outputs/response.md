# Configuring Inactivity Timeout with Session Management

Here's how to configure an 8-hour absolute session with inactivity-based coordination and back-channel logout for the web.app client.

Updated `Program.cs`:

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
    // 8-hour absolute session lifetime
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    // Coordinate client lifetimes with the user session
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;
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
        new Client
        {
            ClientId = "web.app",
            ClientName = "Main Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,

            ClientSecrets = { new Secret("WebAppSecret".Sha256()) },

            RedirectUris = { "https://app.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
            
            // Back-channel logout for session coordination
            BackChannelLogoutUri = "https://app.example.com/bff/backchannel",

            AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

            AllowOfflineAccess = true,
            // Short access token lifetime so refresh tokens signal activity
            AccessTokenLifetime = 300,
            RefreshTokenUsage = TokenUsage.OneTimeOnly,

            AllowedCorsOrigins = { "https://app.example.com" }
        },

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

        new Client
        {
            ClientId = "background.worker",
            ClientName = "Background Worker",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("WorkerSecret".Sha256()) },
            AllowedScopes = { "orders.manage" },
            AccessTokenLifetime = 3600
        },

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

## Key Configuration

- **`CookieLifetime = 8 hours`** with **`CookieSlidingExpiration = false`** gives an 8-hour absolute session
- **`CoordinateClientLifetimesWithUserSession = true`** ties client token lifetimes to the user session
- **`BackChannelLogoutUri`** on web.app allows IdentityServer to notify the client when the session ends
- **`AccessTokenLifetime = 300`** (5 minutes) means the client needs to refresh frequently, keeping the session active through regular token requests

When the session expires due to inactivity, IdentityServer will send a back-channel logout notification to the web.app client's logout URI.
