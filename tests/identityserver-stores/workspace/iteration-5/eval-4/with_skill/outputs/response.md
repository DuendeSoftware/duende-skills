Here's the setup that enables EF-backed server-side sessions and tunes token cleanup to also remove consumed tokens, waiting 300 seconds after consumption before deleting them.

## Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    // Must be enabled before/alongside the operational store so session data is persisted.
    .AddServerSideSessions()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));

        options.EnableTokenCleanup = true;
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 300; // seconds grace period before deleting consumed tokens
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

### Why this works

- **`AddServerSideSessions()`** turns on server-side sessions and registers the `IServerSideSessionStore`. It is called **before/alongside** `AddOperationalStore()` — this ordering matters. If you call it after (or omit it), the operational store never wires up session persistence and session-management features silently degrade to no-ops.
- **`AddOperationalStore(...)`** backs the session store (and grant/device stores) with `PersistedGrantDbContext`. The same operational store also runs token cleanup, which is what removes expired server-side sessions over time.
- **`EnableTokenCleanup = true`** starts the background `TokenCleanupService`.
- **`RemoveConsumedTokens = true`** is required for consumed one-time tokens (e.g., used one-time refresh tokens, authorization codes) to be deleted. Enabling cleanup alone does **not** remove consumed tokens — by default they are soft-deleted (marked with `ConsumedTime`) and retained for threat/replay detection.
- **`ConsumedTokenCleanupDelay = 300`** gives a 300-second grace window after a token is consumed before cleanup deletes it, so a record `ConsumedTime + 300s < UtcNow` before removal.

> Remember to add and apply an EF migration for `PersistedGrantDbContext` so the `ServerSideSessions` table exists:
> ```shell
> dotnet ef migrations add ServerSideSessions -c PersistedGrantDbContext -o Data/Migrations/Operational
> dotnet ef database update -c PersistedGrantDbContext
> ```
