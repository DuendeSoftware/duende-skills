Here's the operational store configured with the advanced cleanup settings you described for a high-traffic, load-balanced deployment.

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        // Dedicated schema for operational tables.
        options.DefaultSchema = "identity_ops";

        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));

        // Cleanup schedule.
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 900;     // 15 minutes, in seconds
        options.TokenCleanupBatchSize = 500;     // tokens removed per cycle

        // Remove consumed tokens after a 10-minute grace period.
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 600; // 10 minutes, in seconds

        // Stagger cleanup start across the 3 instances.
        options.FuzzyTokenCleanupStart = true;
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

### What each setting does

- **`DefaultSchema = "identity_ops"`** puts the operational tables (persisted grants, device codes, keys, sessions) in a custom schema.
- **`EnableTokenCleanup = true`** + **`TokenCleanupInterval = 900`** runs cleanup every 15 minutes.
- **`TokenCleanupBatchSize = 500`** raises how many expired tokens are purged per cycle (from the default of 100), which matters under high volume.
- **`RemoveConsumedTokens = true`** + **`ConsumedTokenCleanupDelay = 600`** deletes consumed one-time tokens 10 minutes after they're used.
- The fuzzy start option staggers the first cleanup run so your three instances don't all hit the database simultaneously.

After changing the schema, generate and apply the operational migration so the tables are created under `identity_ops`.
