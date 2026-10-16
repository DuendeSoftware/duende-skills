# Dynamic identity providers with EF Core

Dynamic providers (Enterprise edition) are loaded from a store at runtime, avoiding the DI cost of hundreds of `AddOpenIdConnect()` registrations and removing the need to restart for config changes.

## Program.cs

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString,
            sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddConfigurationStoreCache()   // by default providers are loaded from the DB on EVERY request
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString,
            sql => sql.MigrationsAssembly(migrationsAssembly));
    });
```

Remove the static `.AddOpenIdConnect("EntraId", ...)` (and any other static provider you're migrating) and keep `AddAuthentication()` only for what stays static. The existing in-memory clients/scopes can stay (or move to the configuration store).

Migrations:

```bash
dotnet ef migrations add Config -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef database update -c ConfigurationDbContext
```

## Seeding the `demoidsrv` provider

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Duende.IdentityServer.Models;

static async Task SeedDynamicProviders(ConfigurationDbContext context)
{
    if (!context.IdentityProviders.Any())
    {
        context.IdentityProviders.Add(new OidcProvider
        {
            Scheme = "demoidsrv",
            DisplayName = "IdentityServer (dynamic)",
            Authority = "https://demo.duendesoftware.com",
            ClientId = "login",
        }.ToEntity());

        await context.SaveChangesAsync();
    }
}

// call at startup
using (var scope = app.Services.CreateScope())
{
    var ctx = scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();
    await ctx.Database.MigrateAsync();
    await SeedDynamicProviders(ctx);
}
```

## Things to know
- `IIdentityProviderStore` is read-only; add/update/delete via `ConfigurationDbContext` (as above) or your own admin mechanism.
- Callback convention: `/federation/{scheme}/signin` (redirect URI), `/federation/{scheme}/signout-callback`, `/federation/{scheme}/signout`. Change with `options.DynamicProviders.PathPrefix`.
- Login page must merge static and dynamic schemes:

```csharp
var providers = (await _schemeProvider.GetAllSchemesAsync())
    .Where(x => x.DisplayName != null)
    .Select(x => new ExternalProvider { DisplayName = x.DisplayName ?? x.Name, AuthenticationScheme = x.Name })
    .ToList();

providers.AddRange((await _identityProviderStore.GetAllSchemeNamesAsync())
    .Where(x => x.Enabled)
    .Select(x => new ExternalProvider { AuthenticationScheme = x.Scheme, DisplayName = x.DisplayName }));
```

- Cached config means store changes appear after the cache expires. Provider client secrets are stored in the DB, so protect it.
