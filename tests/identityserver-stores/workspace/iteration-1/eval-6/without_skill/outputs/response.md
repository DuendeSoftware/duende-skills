# Database Initialization

```csharp
public static void InitializeDatabase(WebApplication app)
{
    using var scope = app.Services.CreateScope();
    var services = scope.ServiceProvider;

    var configContext = services.GetRequiredService<ConfigurationDbContext>();
    configContext.Database.Migrate();

    var grantContext = services.GetRequiredService<PersistedGrantDbContext>();
    grantContext.Database.Migrate();

    // Seed clients
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
        foreach (var scope2 in Config.ApiScopes)
        {
            configContext.ApiScopes.Add(scope2.ToEntity());
        }
        configContext.SaveChanges();
    }
}
```