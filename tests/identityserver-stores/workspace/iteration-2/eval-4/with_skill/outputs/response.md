# Server-Side Sessions with Token Cleanup

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddServerSideSessions()
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
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 300;
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## Key Points

- **`AddServerSideSessions()`** — enables server-side session storage. Session data is persisted in the operational store (`PersistedGrantDbContext`) instead of in cookies.
- **`EnableTokenCleanup = true`** — enables the background cleanup service for expired grants and sessions
- **`RemoveConsumedTokens = true`** — also removes consumed one-time-use tokens (e.g., used authorization codes, one-time refresh tokens) during cleanup
- **`ConsumedTokenCleanupDelay = 300`** — waits 300 seconds (5 minutes) after a token is consumed before deleting it, allowing a grace period for replay detection
- `AddServerSideSessions()` is called before/alongside `AddOperationalStore()` — this is important because the operational store provides the persistence for sessions
