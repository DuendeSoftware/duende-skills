# Converting to Dynamic Identity Providers with EF Core

Dynamic identity providers allow you to load provider configurations from a database at runtime, avoiding the performance overhead of registering hundreds of static authentication handlers via `AddOpenIdConnect()`. This feature requires the **Duende IdentityServer Enterprise Edition**.

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
    // Configure the EF Core configuration store for dynamic providers
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    })
    // Enable caching for dynamic provider lookups
    .AddConfigurationStoreCache()
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

// Static external providers removed — replaced by dynamic providers loaded from the database
// The static AddGoogle and AddOpenIdConnect registrations have been removed.
// Providers are now managed dynamically via the ConfigurationDbContext.

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

## Seeding a Dynamic OIDC Provider

To seed the 'demoidsrv' provider, use the `ConfigurationDbContext` directly:

```csharp
// SeedData.cs
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
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
                DisplayName = "Demo IdentityServer (dynamic)",
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

1. **Removed static `AddGoogle()` and `AddOpenIdConnect("EntraId", ...)` registrations** — These are replaced by dynamic providers loaded from the `ConfigurationDbContext`.

2. **Added `AddConfigurationStore()`** — Configures the EF Core configuration store using the existing SQL Server connection string. This is where dynamic provider definitions are stored.

3. **Added `AddConfigurationStoreCache()`** — Caches dynamic provider lookups to avoid hitting the database on every authentication request. Without this, provider configuration is loaded from the store on every request.

4. **Seed data uses `OidcProvider` entity** — The `OidcProvider` model is used to create a dynamic OIDC provider. It's added to `context.IdentityProviders` with `.ToEntity()` to convert from the model to the EF entity.

## Important Notes

- **Enterprise Edition required**: Dynamic identity providers are part of the Duende IdentityServer Enterprise Edition. This feature is not available in the Community or Business editions.
- Dynamic providers follow the callback path convention `~/federation/{scheme}/signin` for redirect URIs.
- You can still mix static and dynamic providers — only remove the static ones you want to manage dynamically.
