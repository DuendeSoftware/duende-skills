Here's a database initialization method you can call at startup (in development only) that applies migrations for both IdentityServer contexts and seeds the initial clients and API scopes from your `Config` class if they aren't already present.

## Add to Program.cs

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Microsoft.EntityFrameworkCore;

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    InitializeDatabase(app);
}

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();

static void InitializeDatabase(WebApplication app)
{
    using var scope = app.Services.GetRequiredService<IServiceScopeFactory>().CreateScope();
    var services = scope.ServiceProvider;

    // Apply migrations for both contexts.
    services.GetRequiredService<PersistedGrantDbContext>().Database.Migrate();

    var configContext = services.GetRequiredService<ConfigurationDbContext>();
    configContext.Database.Migrate();

    // Seed clients if the table is empty.
    if (!configContext.Clients.Any())
    {
        foreach (var client in Config.Clients)
        {
            configContext.Clients.Add(client.ToEntity());
        }
        configContext.SaveChanges();
    }

    // Seed API scopes if the table is empty.
    if (!configContext.ApiScopes.Any())
    {
        foreach (var apiScope in Config.ApiScopes)
        {
            configContext.ApiScopes.Add(apiScope.ToEntity());
        }
        configContext.SaveChanges();
    }
}
```

### Explanation

- **`CreateScope()`** — the DbContexts are scoped services, so we open a service scope to resolve them safely during startup.
- **`Database.Migrate()`** is called on both `PersistedGrantDbContext` and `ConfigurationDbContext` to create/update their schemas.
- **`!configContext.Clients.Any()`** and **`!configContext.ApiScopes.Any()`** prevent re-seeding on every startup.
- **`.ToEntity()`** (from `Duende.IdentityServer.EntityFramework.Mappers`) maps the in-memory `Client` and `ApiScope` models to EF entities before persisting them.

Because migrating on startup can race across multiple instances, only do this in development — in production, run migrations as a separate deployment step.
