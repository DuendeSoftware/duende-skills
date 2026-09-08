Here's a startup initialization method that migrates both IdentityServer EF contexts and seeds the initial clients and API scopes from your `Config` class when the database is empty. It creates its own DI scope (the contexts are scoped services, so you can't resolve them directly from the root provider), and it guards the seed with an existence check so it won't duplicate data on subsequent runs.

## Add to Program.cs

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Microsoft.EntityFrameworkCore;

// ... build the app ...
var app = builder.Build();

// Development-only: apply migrations and seed initial configuration.
if (app.Environment.IsDevelopment())
{
    InitializeDatabase(app);
}

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();

static void InitializeDatabase(IApplicationBuilder app)
{
    using var scope = app.ApplicationServices
        .GetRequiredService<IServiceScopeFactory>()
        .CreateScope();

    // 1. Apply migrations for both contexts.
    scope.ServiceProvider
        .GetRequiredService<PersistedGrantDbContext>()
        .Database
        .Migrate();

    var configContext = scope.ServiceProvider
        .GetRequiredService<ConfigurationDbContext>();
    configContext.Database.Migrate();

    // 2. Seed clients if none exist yet.
    if (!configContext.Clients.Any())
    {
        foreach (var client in Config.Clients)
        {
            configContext.Clients.Add(client.ToEntity());
        }
        configContext.SaveChanges();
    }

    // 3. Seed API scopes if none exist yet.
    if (!configContext.ApiScopes.Any())
    {
        foreach (var scopeDef in Config.ApiScopes)
        {
            configContext.ApiScopes.Add(scopeDef.ToEntity());
        }
        configContext.SaveChanges();
    }
}
```

### Key details

- **`IServiceScopeFactory.CreateScope()`** — `ConfigurationDbContext` and `PersistedGrantDbContext` are registered as scoped services, so they must be resolved inside an explicit scope during startup rather than from the root service provider.
- **`Database.Migrate()` on both contexts** — this both creates the databases (if missing) and applies any pending migrations for the configuration and operational schemas.
- **`!configContext.Clients.Any()` / `!configContext.ApiScopes.Any()`** — the emptiness checks make seeding idempotent so repeated startups don't insert duplicate rows.
- **`.ToEntity()`** — the mapper extension from `Duende.IdentityServer.EntityFramework.Mappers` converts the IdentityServer model objects (`Client`, `ApiScope`) into their EF entity equivalents before adding them to the context.

> This runs migrations in the app startup path, which is fine for a development environment. For production, apply migrations from a deployment pipeline step (e.g., an init container or CI/CD job) instead of on every node's startup to avoid multi-instance migration races.
