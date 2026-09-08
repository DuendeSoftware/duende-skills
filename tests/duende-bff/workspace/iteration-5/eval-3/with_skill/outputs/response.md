# Production server-side sessions with EF Core + SQL Server

For production you should move sessions server-side and back them with a durable, shared store. The default in-memory cookie session (and even in-memory server-side sessions) are **not** suitable for production — they're lost on restart and can't be shared across instances. Use `Duende.BFF.EntityFramework`.

```bash
dotnet add package Duende.BFF.EntityFramework
```

```csharp
using Duende.Bff;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("BffSessions");

builder.Services.AddBff(options =>
    {
        // ✅ Clean up expired sessions every 10 minutes
        options.SessionCleanupInterval = TimeSpan.FromMinutes(10);
    })
    .ConfigureOpenIdConnect(options =>
    {
        options.Authority    = builder.Configuration["Oidc:Authority"];
        options.ClientId     = builder.Configuration["Oidc:ClientId"];
        options.ClientSecret = builder.Configuration["Oidc:ClientSecret"];
        options.ResponseType = "code";
        options.SaveTokens   = true;
        options.Scope.Add("offline_access");
    })
    // ✅ EF Core-backed server-side sessions on SQL Server
    .AddEntityFrameworkServerSideSessions(options =>
    {
        options.UseSqlServer(connectionString);
    })
    // ✅ v4: the cleanup background service must be registered explicitly
    .AddSessionCleanupBackgroundProcess();

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseRouting();
app.UseAuthentication();
app.UseBff();
app.UseAuthorization();

app.Run();
```

## Key points

- **`AddEntityFrameworkServerSideSessions(...)`** — this is the durable EF store, not `AddServerSideSessions()` alone (which is in-memory only and vanishes on restart / isn't shared across nodes). With server-side sessions the cookie carries only a session id; all tokens (including refresh tokens) live in the SQL store.
- **`UseSqlServer(connectionString)`** — the connection string comes from `ConnectionStrings:BffSessions` via `GetConnectionString("BffSessions")`.
- **`SessionCleanupInterval = TimeSpan.FromMinutes(10)`** sets the cadence, and **`AddSessionCleanupBackgroundProcess()`** actually starts the background cleanup service. This is a v4 change — the old `EnableSessionCleanup` option was removed, so you must call `AddSessionCleanupBackgroundProcess()` explicitly or nothing will clean up.

## Create the schema

The EF store needs its tables. Add and apply a migration:

```bash
dotnet ef migrations add UserSessions -o Migrations -c SessionDbContext
dotnet ef database update
```

That gives you durable, shared, self-cleaning sessions suitable for production.
