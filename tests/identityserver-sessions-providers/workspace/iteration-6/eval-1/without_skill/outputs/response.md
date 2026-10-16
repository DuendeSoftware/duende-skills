# Server-side sessions with EF Core (SQL Server)

`Duende.IdentityServer.EntityFramework` is already referenced, so you only need the operational store plus `AddServerSideSessions()`.

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer(options =>
    {
        // claim copied into the session's DisplayName index
        options.ServerSideSessions.UserDisplayNameClaimType = "name";
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString,
            sql => sql.MigrationsAssembly(migrationsAssembly));
        options.EnableTokenCleanup = true;
    })
    .AddServerSideSessions()          // EF-backed IServerSideSessionStore
    .AddInMemoryIdentityResources(...)  // existing config unchanged
    .AddInMemoryApiScopes(...)
    .AddInMemoryClients(...);
```

Add `using Microsoft.EntityFrameworkCore;`.

Remove the comment saying sessions are cookie-only. Note: `AddServerSideSessions()` registered after `AddOperationalStore` uses the EF store; with no operational store it would fall back to an in-memory store, which isn't production-ready.

## Migrations

```bash
dotnet ef migrations add Sessions -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef database update -c PersistedGrantDbContext
```

This creates the `ServerSideSessions` table (Key, Scheme, SubjectId, SessionId, DisplayName, Created, Renewed, Expires, Ticket).

## Notes
- The `name` claim must be present on the signed-in principal; it is stored in `DisplayName` and is searchable in admin queries.
- Optional tuning: `options.ServerSideSessions.RemoveExpiredSessions`, `RemoveExpiredSessionsFrequency`.
- The `Ticket` column holds the protected authentication ticket, so protect your Data Protection keys (persist them to shared storage if you run multiple instances).
