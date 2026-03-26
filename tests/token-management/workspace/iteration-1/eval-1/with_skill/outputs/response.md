# Client Credentials Token Management for a Worker Service

## Setup

```csharp
// Program.cs
using Duende.AccessTokenManagement;

var builder = Host.CreateApplicationBuilder(args);

// Register token management with a named client
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient(ClientCredentialsClientName.Parse("catalog-worker"), client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("catalog-worker");
        client.ClientSecret = ClientSecret.Parse("worker-secret");
        client.Scope = Scope.Parse("catalog:read");
    });

// Register an HTTP client that automatically acquires and attaches the token
builder.Services.AddClientCredentialsHttpClient(
    "catalog-api",
    ClientCredentialsClientName.Parse("catalog-worker"),
    client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/catalog/");
    });

builder.Services.AddHostedService<CatalogWorker>();

var host = builder.Build();
host.Run();
```

## Worker Service

```csharp
public sealed class CatalogWorker(IHttpClientFactory factory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            // Token acquired, cached, and refreshed transparently
            var client = factory.CreateClient("catalog-api");
            var response = await client.GetAsync("items", stoppingToken);

            if (response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync(stoppingToken);
                // Process catalog data...
            }

            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
        }
    }
}
```

## How It Works

1. **`AddClientCredentialsTokenManagement()`** registers the core token management services including HybridCache-based caching.

2. **`.AddClient()`** defines a named client credentials configuration with the token endpoint, client ID, secret, and scope. The `ClientCredentialsClientName.Parse()` creates a strongly-typed client name.

3. **`AddClientCredentialsHttpClient()`** creates a named HTTP client that automatically:
   - Acquires an access token from the token endpoint
   - Caches the token using HybridCache (in-memory L1 + optional distributed L2)
   - Refreshes the token before it expires (respecting `CacheLifetimeBuffer`)
   - Attaches the token as a Bearer token on every outgoing request
   - Retries once on 401 responses (built-in resiliency handler)

4. The **worker service** simply creates the named client via `IHttpClientFactory` and makes API calls — no manual token code anywhere.
