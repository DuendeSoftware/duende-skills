# Server-side sessions on EF Core / SQL Server

Server-side sessions need Duende IdentityServer **Business or Enterprise** edition. With no store configured they default to **in-memory**, so you must add the EF operational store for production.

```csharp
using Microsoft.EntityFrameworkCore;

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer(options =>
    {
        // Unset (null) by default because of PII concerns; set it explicitly
        options.ServerSideSessions.UserDisplayNameClaimType = "name";
    })
    .AddServerSideSessions()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString,
            sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddInMemoryIdentityResources(/* existing */)
    .AddInMemoryApiScopes(/* existing */)
    .AddInMemoryClients(/* existing */);
```

Replace the "cookie-only" comment. The EF implementation of `IServerSideSessionStore` is part of the operational store, so `AddOperationalStore` is what makes it durable.

**Registration order:** `AddServerSideSessions()` must come *after* any custom `IRefreshTokenService` registration.

## Migrations

```bash
dotnet ef migrations add ServerSideSessions -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef database update -c PersistedGrantDbContext
```

## What is stored
- The serialized `AuthenticationTicket` (claims + `AuthenticationProperties.Items`), protected with ASP.NET Core Data Protection.
- Query indices: **Subject ID** (`sub`), **Session ID** (`sid`), and **Display Name** (the `name` claim, as configured above).

## Production checklist
- Persist and share Data Protection keys across instances, otherwise sessions can't be decrypted.
- The cleanup job (`RemoveExpiredSessions`, default on, every 10 minutes, batch 100) removes expired rows.
- Session lifetime comes from `options.Authentication.CookieLifetime` (default 10 hours), or `ConfigureApplicationCookie` `ExpireTimeSpan` if using ASP.NET Identity.
