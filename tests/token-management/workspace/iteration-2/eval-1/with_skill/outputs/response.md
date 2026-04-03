# Setting Up Client Credentials Token Management for a Worker Service

Here's how to configure Duende.AccessTokenManagement v4 for your .NET 9 worker service to call the catalog API with client credentials, using HttpClientFactory for automatic token management.

## Updated `Program.cs`

```csharp
using Duende.AccessTokenManagement;

var builder = Host.CreateApplicationBuilder(args);

// Register client credentials token management with a named client
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog-worker", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("catalog-worker");
        client.ClientSecret = ClientSecret.Parse("worker-secret");
        client.Scope = Scope.Parse("catalog:read");
    });

// Register an HTTP client that automatically acquires and attaches the client credentials token
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

## Worker Service (`CatalogWorker.cs`)

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

## Key Points

1. **`AddClientCredentialsTokenManagement()`** registers the core token management services.
2. **`.AddClient()`** configures a named client with `TokenEndpoint`, `ClientId`, `ClientSecret`, and `Scope` using v4 strongly-typed setters (`ClientId.Parse()`, `ClientSecret.Parse()`, `Scope.Parse()`).
3. **`AddClientCredentialsHttpClient()`** registers a named HTTP client that automatically acquires, caches, and attaches the access token. It also includes a built-in resiliency handler that retries once on `401 Unauthorized`.
4. **`ClientCredentialsClientName.Parse("catalog-worker")`** is used for the client name — v4 uses strongly-typed names instead of raw strings.
5. The `BackgroundService` uses `IHttpClientFactory.CreateClient("catalog-api")` — no manual token code is needed at the call site. The library handles token acquisition, caching via `HybridCache`, and automatic renewal.

## Package Reference

Make sure your project references:

```xml
<PackageReference Include="Duende.AccessTokenManagement" Version="4.0.0" />
```

No `AddDistributedMemoryCache()` is needed — v4 uses `HybridCache` automatically with an in-memory L1 tier.
