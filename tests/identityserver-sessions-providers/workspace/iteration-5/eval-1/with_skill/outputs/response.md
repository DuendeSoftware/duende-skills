# Production-Ready Server-Side Sessions with EF Core

To make sessions production-ready (durable, queryable, revocable) instead of the default in-memory store, you need to:

1. Call `AddServerSideSessions()` on the IdentityServer builder.
2. Back it with the Entity Framework Core operational store using your existing SQL Server connection string.
3. Set `ServerSideSessions.UserDisplayNameClaimType = "name"` so the user's `name` claim is indexed as the display name.

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
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

// IdentityServer registration — server-side sessions backed by a durable EF Core store
builder.Services.AddIdentityServer(options =>
    {
        // Store the user's "name" claim as the display name in the session index.
        // NOTE: UserDisplayNameClaimType is null (unset) by default because of PII concerns,
        // so it must be set explicitly.
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
    .AddInMemoryClients(new List<Client>
    {
        // ... existing clients unchanged ...
    })
    // 1) Enable server-side sessions (replaces the self-contained cookie state)
    .AddServerSideSessions()
    // 2) Persist sessions in SQL Server via the operational store (durable, not in-memory)
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = db =>
            db.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(migrationsAssembly));
    });
```

## Why this is production-ready

- `AddServerSideSessions()` moves authentication state to the server; the cookie only holds a session reference. This avoids cookie-size growth and enables querying/revoking sessions.
- The EF Core implementation ships as part of the operational store and automatically satisfies the `IServerSideSessionStore` interface — no custom store needed. Because it is backed by SQL Server, sessions survive application restarts (the in-memory default does not).
- `UserDisplayNameClaimType = "name"` populates the queryable **Display Name** index (alongside the `sub`/Subject ID and `sid`/Session ID indices) from the user's `name` claim, so an admin session viewer can show a friendly name.

## Operational notes

- **Migrations**: The operational store includes the `PersistedGrantDbContext` (server-side sessions live here). Add and apply its migration before running:
  ```
  dotnet ef migrations add InitialOperational -c PersistedGrantDbContext
  dotnet ef database update -c PersistedGrantDbContext
  ```
- **Data Protection**: Server-side session data is protected with ASP.NET Core Data Protection. In a load-balanced deployment, persist and share the Data Protection keys across instances or sessions won't decrypt on other nodes.
- **Registration order**: If you register a custom `IRefreshTokenService`, do it *before* `AddServerSideSessions()`.

Your existing connection string `"IdentityServer": "Server=localhost;Database=IdentityServer;..."` from `appsettings.json` is reused via `GetConnectionString("IdentityServer")` — no new configuration required.
