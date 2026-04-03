# Configuring Session Cleanup and Disabling Back-Channel Logout on Expiration

Here's the updated `Program.cs` with custom session cleanup configuration:

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
    // Session cleanup configuration
    options.ServerSideSessions.RemoveExpiredSessions = true;
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);
    options.ServerSideSessions.RemoveExpiredSessionsBatchSize = 200;

    // Randomize the first cleanup run to avoid conflicts in multi-instance deployments
    // This is true by default, but shown explicitly for clarity
    options.ServerSideSessions.FuzzExpiredSessionRemovalStart = true;

    // Disable back-channel logout on session expiration since clients don't support it
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = false;
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
            AccessTokenLifetime = 3600,
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

## Configuration Explained

All settings are on `options.ServerSideSessions`:

| Setting | Value | Purpose |
|---------|-------|---------|
| `RemoveExpiredSessions` | `true` | Enables the automatic cleanup job (this is the default) |
| `RemoveExpiredSessionsFrequency` | `TimeSpan.FromMinutes(5)` | Runs cleanup every 5 minutes (default is 10 minutes) |
| `RemoveExpiredSessionsBatchSize` | `200` | Removes up to 200 expired records per batch (default is 100) |
| `FuzzExpiredSessionRemovalStart` | `true` | Randomizes the first cleanup run timing (default is `true`) — prevents multiple instances from all running cleanup at the same moment |
| `ExpiredSessionsTriggerBackchannelLogout` | `false` | Disables back-channel logout notifications when expired sessions are cleaned up (default is `true`) |

The `FuzzExpiredSessionRemovalStart` option is particularly important in multi-instance deployments. It adds a random delay to the first cleanup run so that not all instances start their cleanup cycle at exactly the same time, which would otherwise cause database contention.
