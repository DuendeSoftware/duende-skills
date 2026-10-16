**Web node** (Program.cs):
```csharp
.AddOperationalStore(o =>
{
    o.ConfigureDbContext = b => b.UseSqlServer(cs, s => s.MigrationsAssembly(asm));
    o.EnableTokenCleanup = false;
});
```

**Worker**:
```csharp
using Duende.IdentityServer.EntityFramework.TokenCleanup; // namespace may vary by version

public class TokenCleanupWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopes;
    private readonly ILogger<TokenCleanupWorker> _logger;
    private static readonly TimeSpan Interval = TimeSpan.FromHours(2);

    public TokenCleanupWorker(IServiceScopeFactory scopes, ILogger<TokenCleanupWorker> logger)
        => (_scopes, _logger) = (scopes, logger);

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        using var timer = new PeriodicTimer(Interval);
        do
        {
            try
            {
                using var scope = _scopes.CreateScope();
                var cleanup = scope.ServiceProvider.GetRequiredService<TokenCleanupService>();
                await cleanup.CleanupGrantsAsync(ct);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { }
            catch (Exception ex) { _logger.LogError(ex, "Token cleanup failed"); }
        }
        while (await timer.WaitForNextTickAsync(ct));
    }
}
```
Registration in the worker host: add the operational store (so DbContext and options exist), register `TokenCleanupService`, then `services.AddHostedService<TokenCleanupWorker>();`. Note `TokenCleanupService` is internal in some versions; if it is, set `EnableTokenCleanup = true` with `TokenCleanupInterval = 7200` in the worker host only, and the built-in host does the same job.
