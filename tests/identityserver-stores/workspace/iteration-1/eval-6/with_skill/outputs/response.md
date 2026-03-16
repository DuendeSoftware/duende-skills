# Database Initialization with EF Core Migrations and Seeding

Here's a startup database initialization method that applies migrations for both contexts and seeds initial data from your `Config` class. This should only be called in development.

Add the following to your `Program.cs`:

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

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
        options.EnableTokenCleanup = true;
    });

var app = builder.Build();

// Only initialize database in development
if (app.Environment.IsDevelopment())
{
    InitializeDatabase(app);
}

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();

static void InitializeDatabase(IApplicationBuilder app)
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

    // Seed clients if empty
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

    // Seed identity resources if empty
    if (!configContext.IdentityResources.Any())
    {
        foreach (var resource in Config.IdentityResources)
        {
            configContext.IdentityResources.Add(resource.ToEntity());
        }
        configContext.SaveChanges();
    }
}

// Static configuration for seeding
public static class Config
{
    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "api-client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        }
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    ];
}
```

**Key points:**

- `InitializeDatabase` creates a service scope via `IServiceScopeFactory.CreateScope()` to resolve scoped services.
- `Database.Migrate()` is called on both `PersistedGrantDbContext` and `ConfigurationDbContext` to apply pending migrations.
- Before seeding, `!configContext.Clients.Any()` checks whether data already exists to avoid duplicate seeding.
- The `.ToEntity()` extension method (from `Duende.IdentityServer.EntityFramework.Mappers`) converts the IdentityServer model objects (`Client`, `ApiScope`, etc.) to their EF entity equivalents. This is required because `ConfigurationDbContext` uses entity types, not the IdentityServer model types directly.

> **Warning:** Do not call `Database.Migrate()` at startup in production multi-node deployments — it causes migration races. Use a deployment pipeline or init container instead.
