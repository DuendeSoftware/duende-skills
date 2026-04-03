# Converting to Dynamic Identity Providers with EF Core

Instead of statically registering each provider with `AddOpenIdConnect()`, you can use Duende IdentityServer's dynamic provider feature to load providers from a database at runtime. This avoids the performance overhead of hundreds of static handler registrations.

## Updated Program.cs

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

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
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
    });

// Removed static AddGoogle and AddOpenIdConnect — providers are now dynamic
builder.Services.AddAuthentication();

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
```

## Seeding a Dynamic Provider

To add a provider to the database, you can seed it using EF Core:

```csharp
// SeedData.cs
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.Models;

public static class SeedData
{
    public static async Task SeedDynamicProviders(ConfigurationDbContext context)
    {
        if (!context.IdentityProviders.Any())
        {
            context.IdentityProviders.Add(new OidcProvider
            {
                Scheme = "demoidsrv",
                DisplayName = "Demo IdentityServer",
                Authority = "https://demo.duendesoftware.com",
                ClientId = "login",
                Enabled = true
            }.ToEntity());

            await context.SaveChangesAsync();
        }
    }
}
```

## Key Changes

1. **Removed static `AddGoogle()` and `AddOpenIdConnect()` calls** — These are replaced by dynamic provider configuration stored in the database.

2. **Added `AddConfigurationStore()`** — Sets up the EF Core configuration store for dynamic providers using the existing SQL Server connection string.

3. **Seed data** — The `OidcProvider` model creates an OIDC provider definition. The `Scheme` is the unique identifier used in authentication challenges.

Run EF migrations to create the configuration store tables before seeding data.
