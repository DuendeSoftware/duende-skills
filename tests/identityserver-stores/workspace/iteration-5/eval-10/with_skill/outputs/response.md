Here's the operational store configured for high-traffic production cleanup: larger batches, a 15-minute interval, a 10-minute consumed-token grace period, fuzzed start to de-sync your 3 instances, and a dedicated `identity_ops` schema.

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "identity_ops";

        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));

        // Automatic cleanup
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 900;      // every 15 minutes (seconds)
        options.TokenCleanupBatchSize = 500;      // 500 tokens per cycle

        // Consumed one-time tokens: remove after a 10-minute grace period
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 600;  // seconds (10 minutes)

        // Avoid all 3 instances firing cleanup at the same instant
        options.FuzzTokenCleanupStart = true;
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

### Option-by-option

| Option | Value | Effect |
|---|---|---|
| `DefaultSchema` | `"identity_ops"` | Operational tables live in the `identity_ops` schema |
| `EnableTokenCleanup` | `true` | Turns on the background `TokenCleanupService` |
| `TokenCleanupInterval` | `900` | Runs cleanup every 15 minutes (value in seconds) |
| `TokenCleanupBatchSize` | `500` | Deletes up to 500 expired records per cleanup cycle (default is 100) |
| `RemoveConsumedTokens` | `true` | Required for consumed one-time tokens to be deleted at all |
| `ConsumedTokenCleanupDelay` | `600` | Waits 600s after consumption before a consumed token is eligible for deletion |
| `FuzzTokenCleanupStart` | `true` | Randomizes the first cleanup run so your 3 load-balanced instances don't race to delete the same rows |

### Notes

- `RemoveConsumedTokens = true` is what makes `ConsumedTokenCleanupDelay` meaningful — without it, consumed tokens are never removed regardless of the delay.
- With `identity_ops` as the schema, scaffold the operational migration so the tables and `__EFMigrationsHistory` land there:
  ```shell
  dotnet ef migrations add InitialOperational -c PersistedGrantDbContext -o Data/Migrations/Operational
  dotnet ef database update -c PersistedGrantDbContext
  ```
