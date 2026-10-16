**Web node:**
```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql => sql.MigrationsAssembly(migrationsAssembly));
        options.EnableTokenCleanup = false;   // cleanup runs in the dedicated worker
    });
```

**Worker:**
```csharp
public sealed class TokenCleanupWorker : BackgroundService
{
    private readonly TokenCleanupService _cleanup;
    private readonly ILogger<TokenCleanupWorker> _logger;

    public TokenCleanupWorker(TokenCleanupService cleanup, ILogger<TokenCleanupWorker> logger)
        => (_cleanup, _logger) = (cleanup, logger);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try { await _cleanup.CleanupGrantsAsync(); }
            catch (Exception ex) when (ex is not OperationCanceledException)
            { _logger.LogError(ex, "Token cleanup failed"); }

            await Task.Delay(TimeSpan.FromHours(2), stoppingToken);
        }
    }
}
```

The worker host must register the operational store (same connection/DbContext config, so `PersistedGrantDbContext` and `TokenCleanupService` dependencies resolve) and the hosted service:
```csharp
builder.Services.AddHostedService<TokenCleanupWorker>();
```
Consider `RemoveConsumedTokens = true` in the options if consumed tokens should also be purged. Cleanup removes expired grants, device codes, PAR requests and server-side sessions.
