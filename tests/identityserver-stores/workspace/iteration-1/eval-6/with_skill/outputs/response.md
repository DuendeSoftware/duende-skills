# Database Initialization with Migrations and Seeding

```csharp
public static void InitializeDatabase(IApplicationBuilder app)
{
    using var serviceScope = app.ApplicationServices
        .GetRequiredService<IServiceScopeFactory>()
        .CreateScope();

    // Apply operational store migrations
    serviceScope.ServiceProvider
        .GetRequiredService<PersistedGrantDbContext>()
        .Database
        .Migrate();

    // Apply configuration store migrations
    var configContext = serviceScope.ServiceProvider
        .GetRequiredService<ConfigurationDbContext>();
    configContext.Database.Migrate();

    // Seed initial data if database is empty
    if (!configContext.Clients.Any())
    {
        foreach (var client in Config.Clients)
        {
            configContext.Clients.Add(client.ToEntity());
        }
        configContext.SaveChanges();
    }

    if (!configContext.ApiScopes.Any())
    {
        foreach (var scope in Config.ApiScopes)
        {
            configContext.ApiScopes.Add(scope.ToEntity());
        }
        configContext.SaveChanges();
    }

    if (!configContext.IdentityResources.Any())
    {
        foreach (var resource in Config.IdentityResources)
        {
            configContext.IdentityResources.Add(resource.ToEntity());
        }
        configContext.SaveChanges();
    }
}
```

Call it after building the app:
```csharp
var app = builder.Build();
InitializeDatabase(app);
```

**Important**: The `.ToEntity()` extension method converts IdentityServer model types (like `Client`) to EF Core entity types. This is provided by `Duende.IdentityServer.EntityFramework.Mappers`.

**Warning**: Don't call `Database.Migrate()` in production multi-node deployments — use a migration pipeline instead.