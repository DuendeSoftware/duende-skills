# Migrating to Dynamic Identity Providers (EF Core)

Registering hundreds of external providers with static `AddOpenIdConnect()` calls forces ASP.NET Core's DI system to build every handler at startup, which is exactly the performance penalty you're hitting. **Dynamic identity providers** load provider configuration from a store at runtime instead, and let you change providers without restarting.

> **Edition note:** Dynamic identity providers are a **Duende IdentityServer Enterprise Edition** feature. Make sure your license covers it before relying on this in production.

## 1) Program.cs — replace static registrations with the dynamic EF store + cache

Remove the static `AddOpenIdConnect("EntraId", ...)` (and any others) and configure the EF-backed dynamic provider store instead. Keep the existing connection string.

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(/* ... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryClients(/* ... */)

    // Configuration store holds dynamic identity providers (ConfigurationDbContext)
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = db =>
            db.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    // Cache dynamic provider lookups so the store isn't hit on every request
    .AddConfigurationStoreCache();

// NOTE: the static .AddOpenIdConnect("EntraId", ...) registration is removed.
// Providers now come from the ConfigurationDbContext at runtime.
builder.Services.AddAuthentication();
```

`AddConfigurationStoreCache()` is important: without it, dynamic provider configuration is read from the database on **every** request. With it, lookups are cached, restoring the startup/runtime performance you were losing.

## 2) Seed the `demoidsrv` OIDC provider

Dynamic OIDC providers are stored as `OidcProvider` entities in the `ConfigurationDbContext`. Seed one for `demoidsrv`:

```csharp
// SeedData.cs
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

private static async Task SeedDynamicProviders(ConfigurationDbContext context)
{
    if (!await context.IdentityProviders.AnyAsync())
    {
        context.IdentityProviders.Add(new OidcProvider
        {
            Scheme = "demoidsrv",
            DisplayName = "IdentityServer (dynamic)",
            Authority = "https://demo.duendesoftware.com",
            ClientId = "login",
            Enabled = true,
        }.ToEntity());

        await context.SaveChangesAsync();
    }
}
```

Note the `.ToEntity()` mapper — it converts the `OidcProvider` model into the EF entity the `ConfigurationDbContext` persists.

## 3) List dynamic providers on the login page

Dynamic providers won't appear via `GetAllSchemesAsync()` alone; merge them from the `IIdentityProviderStore`:

```csharp
var dynamicSchemes = (await _identityProviderStore.GetAllSchemeNamesAsync())
    .Where(x => x.Enabled)
    .Select(x => new ExternalProvider
    {
        AuthenticationScheme = x.Scheme,
        DisplayName = x.DisplayName
    });
providers.AddRange(dynamicSchemes);
```

## Things to remember

- **Store is read-only**: `IIdentityProviderStore` only queries. To add/update/delete providers, write to the `ConfigurationDbContext` directly (as in the seed above).
- **Callback convention**: dynamic providers use `~/federation/{scheme}/signin` for the redirect URI — register `https://demo.duendesoftware.com`'s client `login` with `.../federation/demoidsrv/signin`.
- **Migrations**: apply the `ConfigurationDbContext` migration so the `IdentityProviders` table exists.
