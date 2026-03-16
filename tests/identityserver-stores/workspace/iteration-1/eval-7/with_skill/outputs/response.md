# Dedicated Token Cleanup Worker Service

For high-scale deployments, it's recommended to disable token cleanup on the web nodes and run it as a dedicated background service. This avoids multi-node cleanup conflicts and gives you full control over the cleanup schedule.

## 1. Disable Token Cleanup on the Web Node

Update `Program.cs` to disable the built-in cleanup:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

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

        // Disable token cleanup on web nodes — handled by dedicated worker
        options.EnableTokenCleanup = false;
    });

// Register the dedicated cleanup worker
builder.Services.AddHostedService<TokenCleanupWorker>();

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## 2. TokenCleanupWorker Background Service

```csharp
using Duende.IdentityServer.EntityFramework;

public sealed class TokenCleanupWorker : BackgroundService
{
    private readonly TokenCleanupService _cleanup;
    private readonly ILogger<TokenCleanupWorker> _logger;

    public TokenCleanupWorker(TokenCleanupService cleanup, ILogger<TokenCleanupWorker> logger)
    {
        _cleanup = cleanup;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Token cleanup worker started");

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

            await Task.Delay(TimeSpan.FromHours(2), stoppingToken);
        }

        _logger.LogInformation("Token cleanup worker stopped");
    }
}
```

**Key points:**

- `EnableTokenCleanup = false` disables the built-in background cleanup on the web node.
- `TokenCleanupWorker` inherits from `BackgroundService` and injects `TokenCleanupService` from `Duende.IdentityServer.EntityFramework`.
- `CleanupGrantsAsync()` removes expired persisted grants, device codes, PAR requests, and expired server-side sessions.
- The `while` loop respects the `CancellationToken` so the worker shuts down gracefully.
- The 2-hour delay (`TimeSpan.FromHours(2)`) runs cleanup every 2 hours as requested.
- Error handling ensures the worker continues running even if a single cleanup cycle fails.
