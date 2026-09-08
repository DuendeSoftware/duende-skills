To move token cleanup off the web nodes and into a dedicated worker, disable the built-in cleanup on the web node's operational store and run Duende's `TokenCleanupService` yourself from a `BackgroundService` on a 2-hour cadence.

## 1. Disable cleanup on the web node (Program.cs)

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));

        // The web nodes no longer run cleanup; the dedicated worker owns it.
        options.EnableTokenCleanup = false;
    });
```

## 2. The dedicated worker

```csharp
using Duende.IdentityServer.EntityFramework;

public sealed class TokenCleanupWorker : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly ILogger<TokenCleanupWorker> _logger;

    public TokenCleanupWorker(IServiceProvider services, ILogger<TokenCleanupWorker> logger)
    {
        _services = services;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                // Resolve TokenCleanupService in a scope (it depends on the scoped DbContext).
                using var scope = _services.CreateScope();
                var cleanup = scope.ServiceProvider.GetRequiredService<TokenCleanupService>();
                await cleanup.CleanupGrantsAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Token cleanup run failed");
            }

            await Task.Delay(TimeSpan.FromHours(2), stoppingToken);
        }
    }
}
```

## 3. Register the worker (in the worker host's Program.cs)

The worker process must also register the operational store so `TokenCleanupService` and `PersistedGrantDbContext` are available for injection:

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
        options.EnableTokenCleanup = false; // we drive cleanup manually here too
    });

builder.Services.AddHostedService<TokenCleanupWorker>();
```

### Key points

- **`EnableTokenCleanup = false`** on the web nodes stops the built-in `TokenCleanupHost` there, so the web tier never races the worker to delete the same rows.
- **`TokenCleanupService`** (from `Duende.IdentityServer.EntityFramework`) is the same service the built-in host uses. **`CleanupGrantsAsync()`** removes expired grants, expired device codes, expired PAR entries, and expired server-side sessions (and consumed tokens if `RemoveConsumedTokens` is enabled).
- **Resolving it inside a `using var scope`** each iteration is important — `TokenCleanupService` depends on the scoped `PersistedGrantDbContext`, so you can't inject it directly into the singleton `BackgroundService`.
- **`while (!stoppingToken.IsCancellationRequested)`** plus **`Task.Delay(TimeSpan.FromHours(2), stoppingToken)`** runs cleanup every 2 hours and shuts down cleanly when the host stops.
