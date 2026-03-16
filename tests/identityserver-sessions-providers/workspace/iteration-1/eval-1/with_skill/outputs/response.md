# Enabling Server-Side Sessions with EF Core

To enable server-side sessions with Entity Framework Core and SQL Server, you need to:

1. Call `AddServerSideSessions()` on the IdentityServer builder
2. Configure the operational store with your existing SQL Server connection string
3. Set the display name claim type for session indexing

Here's the updated `Program.cs`:

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

// IdentityServer registration with server-side sessions backed by EF Core
builder.Services.AddIdentityServer(options =>
{
    // Store the user's 'name' claim as the display name in the session index
    options.ServerSideSessions.UserDisplayNameClaimType = "name";
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
    })
    // Enable server-side sessions — replaces the default in-memory cookie-only approach
    .AddServerSideSessions()
    // Use EF Core operational store backed by SQL Server for durable session storage
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(migrationsAssembly));
    });

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

## Key Changes

1. **`AddServerSideSessions()`** — Enables server-side session storage, moving authentication state from the cookie to the server. The cookie now only carries a session reference.

2. **`AddOperationalStore()`** with `UseSqlServer` — Configures the EF Core operational store using the `IdentityServer` connection string already in `appsettings.json`. This replaces the default in-memory store with a durable SQL Server-backed store. You'll need to generate and apply EF Core migrations for the operational store schema.

3. **`ServerSideSessions.UserDisplayNameClaimType = "name"`** — Extracts the user's `name` claim and stores it as the display name in the session index, making it queryable via `ISessionManagementService`. Note that this is null by default due to PII concerns.

**Important**: The default in-memory session store is not suitable for production — sessions would be lost on application restart. The EF Core store ensures sessions survive restarts and can be shared across load-balanced instances (provided Data Protection keys are also shared).
