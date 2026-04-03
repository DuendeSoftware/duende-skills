# Database Initialization

```csharp
using Microsoft.EntityFrameworkCore;

public static class DbInitializer
{
    public static void Initialize(IServiceProvider serviceProvider)
    {
        using var scope = serviceProvider.CreateScope();
        var services = scope.ServiceProvider;

        // Apply migrations
        var configDb = services.GetRequiredService<ConfigurationDbContext>();
        configDb.Database.Migrate();

        var grantDb = services.GetRequiredService<PersistedGrantDbContext>();
        grantDb.Database.Migrate();

        // Seed data
        if (!configDb.Clients.Any())
        {
            foreach (var client in Config.Clients)
            {
                configDb.Clients.Add(MapToEntity(client));
            }
            configDb.SaveChanges();
        }
    }

    private static ClientEntity MapToEntity(Client client)
    {
        // Manual mapping from Client model to entity
        return new ClientEntity { ClientId = client.ClientId };
    }
}
```

Call this at startup for development environments to initialize the database with migrations and seed data.
