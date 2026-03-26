# Enabling Server-Side Sessions in IdentityServer

To move from cookie-only sessions to server-side sessions with SQL Server persistence, you need to enable server-side sessions and configure a database store.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer(options =>
{
    // Configure session display name
    options.ServerSideSessions.UserDisplayNameClaimType = "name";
})
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("catalog.read", "Read access to the catalog"),
        new ApiScope("catalog.write", "Write access to the catalog"),
        new ApiScope("orders.manage", "Manage orders")
    })
    .AddInMemoryClients(Config.Clients) // keeping existing clients
    .AddServerSideSessions()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });

// ... rest of configuration
```

## What This Does

- **`AddServerSideSessions()`** enables server-side session tracking
- **`AddOperationalStore()`** with SQL Server provides durable persistence
- The `name` claim is stored as the display name for admin queries

Run migrations to create the required database tables.