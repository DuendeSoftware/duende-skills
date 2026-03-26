# Token Cleanup Worker Service

## Disable on web node

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
        options.EnableTokenCleanup = false;
    });
```

## Worker

```csharp
public class TokenCleanupWorker : BackgroundService
{
    private readonly IServiceProvider _services;

    public TokenCleanupWorker(IServiceProvider services) => _services = services;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            using var scope = _services.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<PersistedGrantDbContext>();

            var expired = await context.PersistedGrants
                .Where(g => g.Expiration < DateTime.UtcNow)
                .Take(100)
                .ToListAsync();

            context.PersistedGrants.RemoveRange(expired);
            await context.SaveChangesAsync();

            await Task.Delay(TimeSpan.FromHours(2), stoppingToken);
        }
    }
}
```