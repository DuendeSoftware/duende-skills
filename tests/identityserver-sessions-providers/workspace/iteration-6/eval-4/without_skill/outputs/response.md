# Dynamic identity providers with EF Core

Dynamic providers are stored in the configuration store and loaded at request time, so startup doesn't register hundreds of handlers.

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString,
            sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddConfigurationStoreCache()   // caches clients, resources and IdPs
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString,
            sql => sql.MigrationsAssembly(migrationsAssembly));
    });
```

`AddConfigurationStore` registers the IdentityProvider store. `AddConfigurationStoreCache()` requires `AddMemoryCache`/default caching and wraps the stores. You can tune with `options.Caching.IdentityProviderStoreExpiration`. (Move the in-memory clients/scopes to the DB if you want them there too, or keep them in memory.)

Remove the static `AddOpenIdConnect("EntraId", ...)` calls that you want dynamic; keep `AddGoogle` if you want it static. Leave `builder.Services.AddAuthentication()` in place.

## Migrations

```bash
dotnet ef migrations add Config -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef database update -c ConfigurationDbContext
```

## Seeding

```csharp
using var scope = app.Services.CreateScope();
var ctx = scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();
ctx.Database.Migrate();

if (!ctx.IdentityProviders.Any(x => x.Scheme == "demoidsrv"))
{
    ctx.IdentityProviders.Add(new OidcProvider
    {
        Scheme = "demoidsrv",
        DisplayName = "IdentityServer Demo",
        Enabled = true,
        Authority = "https://demo.duendesoftware.com",
        ClientId = "login",
        ResponseType = "id_token",
        Scope = "openid profile"
    }.ToEntity());
    ctx.SaveChanges();
}
```

Usings: `Duende.IdentityServer.EntityFramework.DbContexts`, `Duende.IdentityServer.EntityFramework.Mappers`, `Duende.IdentityServer.Models`.

The built-in dynamic OIDC provider type works out of the box; the callback path defaults to `/federation/{scheme}/signin`, which must be registered at the external IdP. Use `ClientSecret` + `ResponseType = "code"` for code flow. Cache means DB changes can take up to the expiration to apply.
