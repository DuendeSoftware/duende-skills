# Dedicated Token Cleanup Background Worker

## 1. Disable Cleanup on the Web Node

```csharp
// Program.cs (web node)
builder.Services.AddIdentityServer()
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

        // Disable token cleanup on web nodes
        options.EnableTokenCleanup = false;
    });
```

## 2. Create the Token Cleanup Worker

```csharp
// TokenCleanupWorker.cs
using Duende.IdentityServer.EntityFramework;

public class TokenCleanupWorker : BackgroundService
{
    private readonly TokenCleanupService _cleanup;
    private readonly ILogger<TokenCleanupWorker> _logger;

    public TokenCleanupWorker(
        TokenCleanupService cleanup,
        ILogger<TokenCleanupWorker> logger)
    {
        _cleanup = cleanup;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Token cleanup worker starting");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await _cleanup.CleanupGrantsAsync();
                _logger.LogDebug("Token cleanup cycle completed");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during token cleanup");
            }

            // Wait 2 hours before next cleanup
            await Task.Delay(TimeSpan.FromHours(2), stoppingToken);
        }
    }
}
```

## 3. Register the Worker

```csharp
// In the worker service Program.cs
builder.Services.AddHostedService<TokenCleanupWorker>();
```

## Key Points

- **`EnableTokenCleanup = false`** on web nodes prevents the built-in cleanup background service from running
- **`TokenCleanupService`** from `Duende.IdentityServer.EntityFramework` is injected and provides the `CleanupGrantsAsync()` method
- The worker uses a `while` loop that respects `CancellationToken` for graceful shutdown
- The 2-hour delay (`TimeSpan.FromHours(2)`) between cleanup runs avoids cleanup conflicts across nodes
