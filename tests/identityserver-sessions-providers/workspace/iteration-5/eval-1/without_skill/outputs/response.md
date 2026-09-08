# Enabling Server-Side Sessions with EF Core (SQL Server)

By default Duende IdentityServer keeps authentication state in a self-contained cookie. To make sessions durable and queryable in production, enable server-side sessions and back them with a persistent store. The Entity Framework Core operational store is the standard choice.

## Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer(options =>
    {
        // Use the "name" claim as the display name recorded for the session
        options.ServerSideSessions.UserDisplayNameClaimType = "name";
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryClients(/* ... */)
    // Enable server-side sessions
    .AddServerSideSessions()
    // Persist to SQL Server using the existing connection string
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = db =>
            db.UseSqlServer(connectionString);
    });
```

## What changed and why

- **`AddServerSideSessions()`** turns on server-managed sessions. The cookie now only holds a key; the actual ticket lives server-side. This is what allows session querying and revocation.
- **`AddOperationalStore(... UseSqlServer(connectionString))`** persists the sessions (and other operational data like persisted grants) in SQL Server, so they survive restarts. This replaces the in-memory default, which is not production-safe.
- **`UserDisplayNameClaimType = "name"`** tells IdentityServer to index the `name` claim value as the display name for each session, useful for admin listing.

## Database setup

The operational store needs its schema. Generate and apply the EF Core migration for the persisted-grant/operational DbContext, for example:

```bash
dotnet ef migrations add Init -c PersistedGrantDbContext
dotnet ef database update -c PersistedGrantDbContext
```

The connection string `"IdentityServer"` already in `appsettings.json` is used directly, so no additional configuration is needed.

> Tip: In a multi-instance / load-balanced deployment, also configure ASP.NET Core Data Protection to use a shared, persisted key store so session data can be read on every node.
