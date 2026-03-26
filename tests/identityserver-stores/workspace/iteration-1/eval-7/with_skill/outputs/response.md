# Dedicated Token Cleanup Worker

## Disable cleanup on the web node

```csharp
// Program.cs (web node)
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));

        options.EnableTokenCleanup = false; // Disabled on web nodes
    });
```

## TokenCleanupWorker

```csharp
using Duende.IdentityServer.EntityFramework;

public class TokenCleanupWorker : BackgroundService
{
    private readonly TokenCleanupService _cleanup;
    private readonly ILogger<TokenCleanupWorker> _logger;
    private static readonly TimeSpan Interval = TimeSpan.FromHours(2);

    public TokenCleanupWorker(TokenCleanupService cleanup, ILogger<TokenCleanupWorker> logger)
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
                _logger.LogDebug("Running token cleanup");
                await _cleanup.CleanupGrantsAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during token cleanup");
            }

            await Task.Delay(Interval, stoppingToken);
        }
    }
}
```

Register the worker:
```csharp
builder.Services.AddHostedService<TokenCleanupWorker>();
```

`TokenCleanupService` is provided by `Duende.IdentityServer.EntityFramework` and handles removal of expired grants, device codes, PAR requests, and sessions.