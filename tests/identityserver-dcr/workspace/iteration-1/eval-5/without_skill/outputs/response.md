# Persisting Dynamically Registered Clients for Production

For production, you need to persist dynamically registered clients to a database instead of keeping them in memory.

## Setting Up Entity Framework for DCR

Duende IdentityServer provides Entity Framework support for storing clients. You'll want to use the EF-backed configuration store.

### Install the Package

```bash
dotnet add package Duende.IdentityServer.EntityFramework
```

### Configure the Store

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"));
        options.EnableTokenCleanup = true;
    });

builder.Services.AddIdentityServerConfiguration();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.Run();
```

### Run Migrations

You'll need to create and apply EF migrations for the configuration store:

```bash
dotnet ef migrations add InitialIdentityServerConfigurationDbMigration -c ConfigurationDbContext
dotnet ef database update -c ConfigurationDbContext
```

## Important Notes

- **Don't use in-memory stores in production** for DCR clients — they'll be lost on app restart
- Make sure your database connection string is configured in `appsettings.json`
- The configuration store handles both static and dynamically registered clients
- Consider implementing a custom `IClientStore` if you need additional flexibility
