# Database Initialization for IdentityServer

Here's how to write a startup method that applies EF Core migrations and seeds initial data in development:

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    });

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
    using var scope = app.Services.CreateScope();
    var services = scope.ServiceProvider;

    // Apply migrations
    var grantContext = services.GetRequiredService<PersistedGrantDbContext>();
    grantContext.Database.Migrate();

    var configContext = services.GetRequiredService<ConfigurationDbContext>();
    configContext.Database.Migrate();

    // Seed data if empty
    if (!configContext.Clients.Any())
    {
        foreach (var client in Config.Clients)
        {
            configContext.Clients.Add(new Duende.IdentityServer.EntityFramework.Entities.Client
            {
                ClientId = client.ClientId,
                ClientName = client.ClientName,
                AllowedGrantTypes = client.AllowedGrantTypes
                    .Select(gt => new Duende.IdentityServer.EntityFramework.Entities.ClientGrantType { GrantType = gt })
                    .ToList()
            });
        }
        configContext.SaveChanges();
    }

    if (!configContext.ApiScopes.Any())
    {
        foreach (var scope2 in Config.ApiScopes)
        {
            configContext.ApiScopes.Add(new Duende.IdentityServer.EntityFramework.Entities.ApiScope
            {
                Name = scope2.Name,
                DisplayName = scope2.DisplayName
            });
        }
        configContext.SaveChanges();
    }
}
```

This applies migrations for both EF Core contexts and seeds the database with your `Config` data if it's empty. The development-only check ensures you don't accidentally run migrations in production.
