# Dedicated Token Cleanup Background Worker

Here's how to move token cleanup to a dedicated background service:

## Disable Cleanup on Web Node

```csharp
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

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

        options.EnableTokenCleanup = false; // Disable on web node
    });

builder.Services.AddHostedService<TokenCleanupWorker>();

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## TokenCleanupWorker

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Microsoft.EntityFrameworkCore;

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
                var context = scope.ServiceProvider.GetRequiredService<PersistedGrantDbContext>();

                // Remove expired grants
                var expired = await context.PersistedGrants
                    .Where(g => g.Expiration < DateTime.UtcNow)
                    .ToListAsync(stoppingToken);

                if (expired.Any())
                {
                    context.PersistedGrants.RemoveRange(expired);
                    await context.SaveChangesAsync(stoppingToken);
                    _logger.LogInformation("Cleaned up {Count} expired grants", expired.Count);
                }

                // Remove expired device codes
                var expiredDeviceCodes = await context.DeviceFlowCodes
                    .Where(d => d.Expiration < DateTime.UtcNow)
                    .ToListAsync(stoppingToken);

                if (expiredDeviceCodes.Any())
                {
                    context.DeviceFlowCodes.RemoveRange(expiredDeviceCodes);
                    await context.SaveChangesAsync(stoppingToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error cleaning up expired tokens");
            }

            await Task.Delay(TimeSpan.FromHours(2), stoppingToken);
        }
    }
}
```

This worker runs every 2 hours, queries the `PersistedGrantDbContext` for expired grants and device codes, and removes them. The web node has `EnableTokenCleanup = false` so it won't run its own cleanup.
