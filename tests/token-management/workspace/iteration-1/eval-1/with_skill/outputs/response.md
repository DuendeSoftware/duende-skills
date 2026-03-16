# Client Credentials Token Management for Worker Service

Here's the complete setup using Duende.AccessTokenManagement v4 with HttpClientFactory:

```csharp
// Program.cs
using Duende.AccessTokenManagement;

var builder = Host.CreateApplicationBuilder(args);

// Register client credentials token management with a named client
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("catalog-worker");
        client.ClientSecret = ClientSecret.Parse("worker-secret");
        client.Scope = Scope.Parse("catalog:read");
    });

// Register an HTTP client that automatically acquires and attaches the token
builder.Services.AddClientCredentialsHttpClient(
    "catalog-api",
    ClientCredentialsClientName.Parse("catalog.client"),
    client => { client.BaseAddress = new Uri("https://api.example.com/catalog/"); });

// Register the worker service
builder.Services.AddHostedService<CatalogWorker>();

var host = builder.Build();
host.Run();

// Worker service
public sealed class CatalogWorker(IHttpClientFactory factory, ILogger<CatalogWorker> logger)
    : BackgroundService
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
                logger.LogInformation("Catalog response: {Content}", content);
            }
            else
            {
                logger.LogWarning("API call failed: {Status}", response.StatusCode);
            }

            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}
```

## Key Points

1. **`AddClientCredentialsTokenManagement()`** registers the token management services.
2. **`AddClient()`** configures the named client with `TokenEndpoint`, `ClientId`, `ClientSecret`, and `Scope` using v4 strongly-typed property setters (`ClientId.Parse()`, `ClientSecret.Parse()`, `Scope.Parse()`).
3. **`AddClientCredentialsHttpClient()`** registers a named HTTP client that automatically acquires, caches, and attaches the token. It also includes a built-in resiliency handler that retries once on 401 Unauthorized.
4. **`ClientCredentialsClientName.Parse("catalog.client")`** — v4 uses strongly-typed client names instead of raw strings.
5. The `CatalogWorker` uses `IHttpClientFactory.CreateClient` with no manual token code.
