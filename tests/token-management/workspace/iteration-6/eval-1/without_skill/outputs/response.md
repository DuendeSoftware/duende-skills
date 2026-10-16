# Worker service calling the catalog API with client credentials

```csharp
using Duende.AccessTokenManagement;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("catalog-worker");
        client.ClientSecret = ClientSecret.Parse("worker-secret");
        client.Scope = Scope.Parse("catalog:read");
    });

builder.Services.AddClientCredentialsHttpClient("catalog", ClientCredentialsClientName.Parse("catalog.client"), http =>
{
    http.BaseAddress = new Uri("https://api.example.com/catalog/");
});

builder.Services.AddHostedService<CatalogWorker>();
await builder.Build().RunAsync();
```

```csharp
public class CatalogWorker(IHttpClientFactory factory, ILogger<CatalogWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            var http = factory.CreateClient("catalog");
            var response = await http.GetAsync("items", ct);
            logger.LogInformation("Catalog returned {Status}", response.StatusCode);
            await Task.Delay(TimeSpan.FromMinutes(1), ct);
        }
    }
}
```

Notes:
- Tokens are requested, cached and renewed automatically; the handler attaches the bearer token.
- Create the client per call via `CreateClient` (don't hold on to it forever).
- Move the secret out of code (user secrets / env vars / configuration) in real deployments. Only `Duende.AccessTokenManagement` is needed for the worker; the `.OpenIdConnect` package is for user tokens in web apps.
