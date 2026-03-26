# Minimal Client Credentials Token Management — Duende.AccessTokenManagement v4

Here's the simplest possible setup for a .NET 9 worker service:

## Package

```bash
dotnet add package Duende.AccessTokenManagement
```

## Program.cs

```csharp
var builder = Host.CreateApplicationBuilder(args);

// Register client credentials token management with a named client
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("api.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("my-service");
        client.ClientSecret = ClientSecret.Parse("my-secret");
        client.Scope = Scope.Parse("api1");
    });

// Register an HTTP client that automatically acquires and attaches the token
builder.Services.AddClientCredentialsHttpClient(
    "api",
    ClientCredentialsClientName.Parse("api.client"),
    client => { client.BaseAddress = new Uri("https://api.example.com/"); });

builder.Services.AddHostedService<Worker>();

var host = builder.Build();
host.Run();
```

## Worker.cs

```csharp
public sealed class Worker(IHttpClientFactory factory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var client = factory.CreateClient("api");
            var response = await client.GetAsync("data", stoppingToken);
            // process response...
            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}
```

That's it. The library handles:
- **Token acquisition** — requests a token from the token endpoint on first use
- **Caching** — caches the token using `HybridCache` (in-memory L1 by default)
- **Refresh** — re-requests a token before it expires (based on `CacheLifetimeBuffer`, default 60s)
- **Resiliency** — `AddClientCredentialsHttpClient` includes a built-in retry handler for 401 responses
