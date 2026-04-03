# Database Initialization with EF Core Migrations and Seeding

## InitializeDatabase Method

```csharp
// DatabaseInitializer.cs
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Microsoft.EntityFrameworkCore;

public static class DatabaseInitializer
{
    public static void InitializeDatabase(IApplicationBuilder app)
    {
        using var serviceScope = app.ApplicationServices
            .GetRequiredService<IServiceScopeFactory>()
            .CreateScope();

        // Apply migrations for the operational store
        serviceScope.ServiceProvider
            .GetRequiredService<PersistedGrantDbContext>()
            .Database
            .Migrate();

        // Apply migrations for the configuration store
        var configContext = serviceScope.ServiceProvider
            .GetRequiredService<ConfigurationDbContext>();
        configContext.Database.Migrate();

        // Seed initial client data if the database is empty
        if (!configContext.Clients.Any())
        {
            foreach (var client in Config.Clients)
            {
                configContext.Clients.Add(client.ToEntity());
            }
            configContext.SaveChanges();
        }

        // Seed API scopes if empty
        if (!configContext.ApiScopes.Any())
        {
            foreach (var scope in Config.ApiScopes)
            {
                configContext.ApiScopes.Add(scope.ToEntity());
            }
            configContext.SaveChanges();
        }
    }
}
```

## Usage in Program.cs

```csharp
var app = builder.Build();

// Development only — apply migrations and seed data
if (app.Environment.IsDevelopment())
{
    DatabaseInitializer.InitializeDatabase(app);
}

app.UseIdentityServer();
app.Run();
```

## Key Points

- **`CreateScope()`** — creates a scoped service provider for resolving DbContexts
- **`Database.Migrate()`** — applies pending EF Core migrations for both contexts
- **`!configContext.Clients.Any()`** — checks if data already exists before seeding to avoid duplicates
- **`.ToEntity()`** — converts from the IdentityServer model (`Client`) to the EF entity (`Duende.IdentityServer.EntityFramework.Entities.Client`)
- This should only run in development/staging — in production, use a deployment pipeline for migrations
