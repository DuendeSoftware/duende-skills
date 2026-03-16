# Advanced Token Cleanup Configuration for High-Traffic Production

Here's the `Program.cs` with all the advanced operational store settings:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "identity_ops";

        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));

        // Enable token cleanup
        options.EnableTokenCleanup = true;

        // Run cleanup every 15 minutes (900 seconds)
        options.TokenCleanupInterval = 900;

        // Process 500 tokens per cleanup cycle
        options.TokenCleanupBatchSize = 500;

        // Remove consumed one-time tokens
        options.RemoveConsumedTokens = true;

        // 10-minute grace period before removing consumed tokens (600 seconds)
        options.ConsumedTokenCleanupDelay = 600;

        // Randomize first cleanup start to avoid conflicts across 3 instances
        options.FuzzTokenCleanupStart = true;
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

**Settings explanation:**

| Setting | Value | Purpose |
|---|---|---|
| `DefaultSchema` | `"identity_ops"` | All operational tables placed in the `identity_ops` schema |
| `EnableTokenCleanup` | `true` | Enables the background cleanup service |
| `TokenCleanupInterval` | `900` | Cleanup runs every 15 minutes (900 seconds) |
| `TokenCleanupBatchSize` | `500` | Removes up to 500 expired tokens per cycle (default is 100) |
| `RemoveConsumedTokens` | `true` | Also cleans up consumed one-time tokens (e.g., used refresh tokens) |
| `ConsumedTokenCleanupDelay` | `600` | Waits 10 minutes (600 seconds) after consumption before removing |
| `FuzzTokenCleanupStart` | `true` | Randomizes the first cleanup run within the interval to prevent all 3 nodes from cleaning up simultaneously |

**Notes for your 3-instance deployment:**
- `FuzzTokenCleanupStart = true` prevents all 3 instances from starting cleanup at exactly the same time, reducing database contention.
- The batch size of 500 is tuned for high-traffic — the default of 100 may not keep up with token accumulation under heavy load.
- `ConsumedTokenCleanupDelay = 600` provides a 10-minute window for replay detection on consumed tokens before they're permanently removed.
