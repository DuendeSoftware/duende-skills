# Client Credentials with Duende.AccessTokenManagement in a Worker Service

You can use `Duende.AccessTokenManagement` together with `IHttpClientFactory` so the worker never has to fetch or attach tokens itself. Here's how to wire it up.

## 1. Install the package

```bash
dotnet add package Duende.AccessTokenManagement
```

## 2. Program.cs

```csharp
var builder = Host.CreateApplicationBuilder(args);

// Register client credentials token management
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog", client =>
    {
        client.TokenEndpoint = "https://sts.example.com/connect/token";
        client.ClientId = "catalog-worker";
        client.ClientSecret = "worker-secret";
        client.Scope = "catalog:read";
    });

// Register an HttpClient that automatically attaches the access token
builder.Services.AddClientCredentialsHttpClient("catalog-client", "catalog", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/catalog/");
});

builder.Services.AddHostedService<CatalogWorker>();

var host = builder.Build();
host.Run();
```

## 3. The background service

```csharp
public class CatalogWorker : BackgroundService
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<CatalogWorker> _logger;

    public CatalogWorker(IHttpClientFactory httpClientFactory, ILogger<CatalogWorker> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            // The token is fetched, cached and attached automatically
            var client = _httpClientFactory.CreateClient("catalog-client");

            var response = await client.GetAsync("items", stoppingToken);
            if (response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(stoppingToken);
                _logger.LogInformation("Catalog: {Body}", body);
            }

            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}
```

## How it works

- `AddClientCredentialsTokenManagement().AddClient(...)` registers a named client with your token endpoint, client id/secret, and scope.
- `AddClientCredentialsHttpClient(...)` creates a named `HttpClient` and attaches a delegating handler that requests a token (using the client credentials grant), caches it, and adds it as a `Bearer` header on every outgoing request. When the token expires it is automatically renewed.
- The worker just resolves the client from `IHttpClientFactory` and makes calls — no `HttpClient.SetBearerToken()` or manual token requests needed.

For a distributed / multi-instance deployment, register a distributed cache (e.g. `AddStackExchangeRedisCache`) so cached tokens are shared, and consider storing the client secret in a secret store rather than in code.
