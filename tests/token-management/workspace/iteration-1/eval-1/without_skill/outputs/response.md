# Client Credentials Token Management for Worker Service

Here's how to set up token management for a worker service using Duende.AccessTokenManagement:

```csharp
// Program.cs
var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog-client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = "catalog-worker";
        client.ClientSecret = "worker-secret";
        client.Scope = "catalog:read";
    });

builder.Services.AddHttpClient("catalog-api", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/catalog/");
}).AddClientCredentialsTokenHandler("catalog-client");

builder.Services.AddHostedService<CatalogWorker>();

var host = builder.Build();
host.Run();

public class CatalogWorker : BackgroundService
{
    private readonly IHttpClientFactory _factory;
    private readonly ILogger<CatalogWorker> _logger;

    public CatalogWorker(IHttpClientFactory factory, ILogger<CatalogWorker> logger)
    {
        _factory = factory;
        _logger = logger;
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
                _logger.LogInformation("Got: {Content}", content);
            }

            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}
```

This sets up automatic token acquisition and caching. The HTTP client will automatically get a token before making API calls.
