```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Microsoft.EntityFrameworkCore;

public static class DatabaseInitializer
{
    public static async Task InitializeAsync(IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var sp = scope.ServiceProvider;

        await sp.GetRequiredService<PersistedGrantDbContext>().Database.MigrateAsync();
        var context = sp.GetRequiredService<ConfigurationDbContext>();
        await context.Database.MigrateAsync();

        if (!await context.Clients.AnyAsync())
        {
            foreach (var c in Config.Clients) context.Clients.Add(c.ToEntity());
            await context.SaveChangesAsync();
        }
        if (!await context.ApiScopes.AnyAsync())
        {
            foreach (var s in Config.ApiScopes) context.ApiScopes.Add(s.ToEntity());
            await context.SaveChangesAsync();
        }
        if (!await context.IdentityResources.AnyAsync())
        {
            foreach (var r in Config.IdentityResources) context.IdentityResources.Add(r.ToEntity());
            await context.SaveChangesAsync();
        }
    }
}
```

In Program.cs, after `builder.Build()`:
```csharp
if (app.Environment.IsDevelopment())
    await DatabaseInitializer.InitializeAsync(app.Services);
```
Dev only: running migrations at startup isn't safe for multi-instance production.
