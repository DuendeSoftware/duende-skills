# Dynamic Identity Providers with Entity Framework Core

Dynamic identity providers solve the performance problem of registering hundreds of static authentication handlers. Instead of adding them all at startup, providers are loaded from a database at runtime.

**Important**: Dynamic identity providers require the **Duende IdentityServer Enterprise Edition**.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Microsoft.EntityFrameworkCore;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
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
    // Use EF Core configuration store for dynamic identity providers
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    // Enable caching for dynamic provider lookups
    .AddConfigurationStoreCache();

// Remove the static Google and EntraId registrations — they will be loaded dynamically
// builder.Services.AddAuthentication()
//     .AddGoogle("Google", ...) — REMOVED, now a dynamic provider
//     .AddOpenIdConnect("EntraId", ...) — REMOVED, now a dynamic provider

builder.Services.AddRazorPages();

var app = builder.Build();

// Seed dynamic providers
await SeedDynamicProviders(app);

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

app.Run();

// Seed data
static async Task SeedDynamicProviders(WebApplication app)
{
    using var scope = app.Services.CreateScope();
    var context = scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();

    if (!context.IdentityProviders.Any())
    {
        context.IdentityProviders.Add(new OidcProvider
        {
            Scheme = "demoidsrv",
            DisplayName = "Demo IdentityServer (dynamic)",
            Authority = "https://demo.duendesoftware.com",
            ClientId = "login",
        }.ToEntity());

        await context.SaveChangesAsync();
    }
}
```

## Key Changes

1. **Removed static `AddGoogle()` and `AddOpenIdConnect()` registrations** — These were causing startup performance issues with hundreds of providers. Dynamic providers are loaded on-demand from the database.

2. **`AddConfigurationStore()`** — Configures the EF Core configuration store using the existing SQL Server connection string. This stores dynamic identity providers in the `ConfigurationDbContext`.

3. **`AddConfigurationStoreCache()`** — Enables caching for dynamic provider lookups. Without this, provider configuration would be loaded from the database on every request.

4. **Seed data** — An `OidcProvider` is seeded with `Scheme = "demoidsrv"`, `Authority = "https://demo.duendesoftware.com"`, and `ClientId = "login"`. The `.ToEntity()` call converts the model to an EF Core entity for storage.

## How Dynamic Providers Work

- Providers are loaded from the store at runtime, avoiding DI overhead
- The callback path follows the convention `~/federation/{scheme}/signin`
- To manage providers (add/update/delete), use `ConfigurationDbContext` directly — `IIdentityProviderStore` is read-only
- To list dynamic providers on the login page, query `IIdentityProviderStore.GetAllSchemeNamesAsync()` and merge with static schemes
