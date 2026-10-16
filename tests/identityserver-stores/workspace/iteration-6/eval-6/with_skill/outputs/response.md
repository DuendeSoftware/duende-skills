```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Microsoft.EntityFrameworkCore;

public static class DatabaseInitializer
{
    public static void InitializeDatabase(IApplicationBuilder app)
    {
        using var serviceScope = app.ApplicationServices
            .GetRequiredService<IServiceScopeFactory>().CreateScope();

        serviceScope.ServiceProvider.GetRequiredService<PersistedGrantDbContext>().Database.Migrate();

        var context = serviceScope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();
        context.Database.Migrate();

        if (!context.Clients.Any())
        {
            foreach (var client in Config.Clients) context.Clients.Add(client.ToEntity());
            context.SaveChanges();
        }
        if (!context.ApiScopes.Any())
        {
            foreach (var scope in Config.ApiScopes) context.ApiScopes.Add(scope.ToEntity());
            context.SaveChanges();
        }
        if (!context.IdentityResources.Any())
        {
            foreach (var r in Config.IdentityResources) context.IdentityResources.Add(r.ToEntity());
            context.SaveChanges();
        }
    }
}
```

In Program.cs, after `builder.Build()`:
```csharp
if (app.Environment.IsDevelopment())
{
    DatabaseInitializer.InitializeDatabase(app);
}
```
Guarding with `IsDevelopment()` matters: auto-migrating on startup races across instances in multi-node deployments, so in production run migrations in a deployment pre-step. This assumes `AddConfigurationStore`/`AddOperationalStore` use `MigrationsAssembly` set to the host project.
