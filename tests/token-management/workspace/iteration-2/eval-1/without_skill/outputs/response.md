# Setting Up Client Credentials Token Management for a Worker Service

Here's how to set up token management for your .NET 9 worker service to call the catalog API using client credentials.

## `Program.cs`

```csharp
using Duende.AccessTokenManagement;

var builder = Host.CreateApplicationBuilder(args);

// Configure token management
builder.Services.AddDistributedMemoryCache();
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog-worker", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = "catalog-worker";
        client.ClientSecret = "worker-secret";
        client.Scope = "catalog:read";
    });

// Register an HTTP client with token management
builder.Services.AddHttpClient("catalog-api", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/catalog/");
}).AddClientCredentialsTokenHandler("catalog-worker");

builder.Services.AddHostedService<CatalogWorker>();

var host = builder.Build();
host.Run();
```

## Worker Service

```csharp
public sealed class CatalogWorker : BackgroundService
{
    private readonly IHttpClientFactory _factory;

    public CatalogWorker(IHttpClientFactory factory)
    {
        _factory = factory;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var client = _factory.CreateClient("catalog-api");
            var response = await client.GetAsync("items", stoppingToken);

            if (response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync(stoppingToken);
                // Process catalog data
            }

            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
        }
    }
}
```

## Notes

- `AddClientCredentialsTokenManagement()` registers the token management infrastructure.
- `AddClient()` configures the named client with the token endpoint, credentials, and scope.
- `AddClientCredentialsTokenHandler()` attaches a delegating handler that automatically manages tokens.
- Make sure to add `AddDistributedMemoryCache()` for token caching.
