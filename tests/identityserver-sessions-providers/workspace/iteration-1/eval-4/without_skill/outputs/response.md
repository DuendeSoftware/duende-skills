# Dynamic Identity Providers with Entity Framework Core

To manage identity providers dynamically instead of static registrations, you can store them in the database and load them at runtime.

## Updated Configuration

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });

// Keep Google as static, move OIDC providers to dynamic
builder.Services.AddAuthentication()
    .AddGoogle("Google", options =>
    {
        options.ClientId = builder.Configuration["ExternalProviders:Google:ClientId"]!;
        options.ClientSecret = builder.Configuration["ExternalProviders:Google:ClientSecret"]!;
    });
```

## Seeding a Provider

```csharp
// Seed data for the demo provider
using var scope = app.Services.CreateScope();
var context = scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();

if (!context.IdentityProviders.Any())
{
    context.IdentityProviders.Add(new OidcProvider
    {
        Scheme = "demoidsrv",
        Authority = "https://demo.duendesoftware.com",
        ClientId = "login"
    }.ToEntity());

    await context.SaveChangesAsync();
}
```

## Notes

- Dynamic providers avoid the DI overhead of registering many handlers at startup
- Store provider configuration in the database for runtime management
- Consider caching for performance with many providers