You can enable server-side sessions and configure consumed-token cleanup through the operational store options. Here's the setup.

## Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));

        options.EnableTokenCleanup = true;
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 300; // seconds
    })
    .AddServerSideSessions();

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

### What this does

- **`AddServerSideSessions()`** enables server-side session storage. Backed by the EF operational store, session data is written to the `PersistedGrantDbContext` (a `ServerSideSessions` table). This lets you centrally manage and revoke sessions instead of relying solely on the auth cookie.
- **`EnableTokenCleanup = true`** starts the background cleanup service that periodically removes expired operational data.
- **`RemoveConsumedTokens = true`** ensures tokens that have been consumed (used once) are also removed during cleanup, rather than being kept around indefinitely.
- **`ConsumedTokenCleanupDelay = 300`** waits 300 seconds after a token is consumed before it becomes eligible for deletion, giving a short grace window.

Don't forget to create and apply a migration for the operational context so the server-side sessions table is present:

```bash
dotnet ef migrations add AddServerSideSessions -c PersistedGrantDbContext
dotnet ef database update -c PersistedGrantDbContext
```
