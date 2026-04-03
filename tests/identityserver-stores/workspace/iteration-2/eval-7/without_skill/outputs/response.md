# Background Token Cleanup Worker

## Disable on web node:

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
        options.EnableTokenCleanup = false;
    });
```

## Worker:

```csharp
public class TokenCleanupWorker : BackgroundService
{
    private readonly IServiceProvider _provider;

    public TokenCleanupWorker(IServiceProvider provider)
    {
        _provider = provider;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            using var scope = _provider.CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<PersistedGrantDbContext>();

            // Delete expired grants
            var expired = await dbContext.PersistedGrants
                .Where(g => g.Expiration < DateTime.UtcNow)
                .ToListAsync(stoppingToken);

            dbContext.PersistedGrants.RemoveRange(expired);
            await dbContext.SaveChangesAsync(stoppingToken);

            await Task.Delay(TimeSpan.FromHours(2), stoppingToken);
        }
    }
}
```

Register as a hosted service: `builder.Services.AddHostedService<TokenCleanupWorker>();`
