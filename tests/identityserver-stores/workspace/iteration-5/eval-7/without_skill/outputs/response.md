You can offload token cleanup to a dedicated background worker by turning off the built-in cleanup on the web node and running `TokenCleanupService` on your own schedule.

## 1. Disable cleanup on the web node

In the web app's `Program.cs`, set `EnableTokenCleanup` to false on the operational store:

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));

        options.EnableTokenCleanup = false;
    });
```

## 2. Create the TokenCleanupWorker

```csharp
using Duende.IdentityServer.EntityFramework;

public class TokenCleanupWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<TokenCleanupWorker> _logger;

    public TokenCleanupWorker(IServiceScopeFactory scopeFactory, ILogger<TokenCleanupWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var tokenCleanup = scope.ServiceProvider.GetRequiredService<TokenCleanupService>();
                await tokenCleanup.RemoveExpiredGrantsAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error running token cleanup");
            }

            await Task.Delay(TimeSpan.FromHours(2), stoppingToken);
        }
    }
}
```

## 3. Register the worker

```csharp
builder.Services.AddHostedService<TokenCleanupWorker>();
```

### Notes

- **`EnableTokenCleanup = false`** stops the web node from running the cleanup loop itself.
- The worker inherits from **`BackgroundService`** and runs a loop that respects the `CancellationToken`, waiting **2 hours** (`TimeSpan.FromHours(2)`) between runs.
- **`TokenCleanupService`** (from `Duende.IdentityServer.EntityFramework`) is resolved from a DI scope on each pass, since it depends on the scoped grant DbContext, and then invoked to purge expired operational data.

Make sure the worker host also registers the operational store so `TokenCleanupService` and its `PersistedGrantDbContext` dependency are available.
