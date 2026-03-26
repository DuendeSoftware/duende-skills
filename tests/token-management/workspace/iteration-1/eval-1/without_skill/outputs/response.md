# Client Credentials with HttpClientFactory

```csharp
// Program.cs
var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog-worker", client =>
    {
        client.TokenEndpoint = "https://sts.example.com/connect/token";
        client.ClientId = "catalog-worker";
        client.ClientSecret = "worker-secret";
        client.Scope = "catalog:read";
    });

builder.Services.AddClientCredentialsHttpClient(
    "catalog-api",
    "catalog-worker",
    client => client.BaseAddress = new Uri("https://api.example.com/catalog/"));

builder.Services.AddHostedService<CatalogWorker>();

var host = builder.Build();
host.Run();
```

## Worker

```csharp
public class CatalogWorker : BackgroundService
{
    private readonly IHttpClientFactory _factory;
    public CatalogWorker(IHttpClientFactory factory) => _factory = factory;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var client = _factory.CreateClient("catalog-api");
            var response = await client.GetAsync("items", stoppingToken);
            // process response
            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
        }
    }
}
```

The token management library handles acquiring, caching, and refreshing the access token automatically.
