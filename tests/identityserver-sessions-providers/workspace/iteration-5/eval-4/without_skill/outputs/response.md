# Switching to Dynamic Identity Providers with EF Core

Static `AddOpenIdConnect()` registrations build an authentication handler per provider at startup, which does not scale to hundreds of providers. Duende IdentityServer's **dynamic identity providers** load provider configuration from a database at runtime, so you avoid the DI overhead and can change providers without a restart.

## 1) Program.cs — use the configuration store instead of static registrations

Drop the static `AddOpenIdConnect("EntraId", ...)` call and configure the EF Core configuration store, which holds the dynamic providers. Reuse the existing connection string.

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(/* ... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryClients(/* ... */)
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = db => db.UseSqlServer(connectionString);
    })
    // cache the provider store so it isn't queried on every request
    .AddConfigurationStoreCache();

// The static EntraId AddOpenIdConnect registration is removed.
builder.Services.AddAuthentication();
```

The `AddConfigurationStoreCache()` call adds caching so dynamic provider lookups don't hit the database on every request.

## 2) Seed a dynamic OIDC provider for demoidsrv

Add an `OidcProvider` to the `ConfigurationDbContext`:

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Duende.IdentityServer.Models;

static async Task SeedProviders(ConfigurationDbContext context)
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
```

The `.ToEntity()` extension maps the model onto the EF entity stored in the configuration database.

## 3) Show dynamic providers on the login page

Query the identity provider store and merge with the static schemes when building the list of external providers on your login page, e.g. using `IIdentityProviderStore.GetAllSchemeNamesAsync()` and filtering by `Enabled`.

## Notes

- Apply the EF Core migration for the `ConfigurationDbContext` so the `IdentityProviders` table exists before seeding.
- Dynamic providers use callback paths under `/federation/{scheme}/...`, so register the client redirect URI accordingly at the upstream provider.
- To add/update providers at runtime, write to the `ConfigurationDbContext`; the provider store itself is query-only.
