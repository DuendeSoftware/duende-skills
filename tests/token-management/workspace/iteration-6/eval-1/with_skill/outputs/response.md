# Worker service with client credentials (Duende.AccessTokenManagement v4)

The worker only needs `Duende.AccessTokenManagement` (the `.OpenIdConnect` package is for user tokens in web apps).

```csharp
using Duende.AccessTokenManagement;

var builder = Host.CreateApplicationBuilder(args);

// Named client definition: how to get the token
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("catalog-worker");
        client.ClientSecret = ClientSecret.Parse(builder.Configuration["Catalog:ClientSecret"]!); // 'worker-secret' – keep in secrets/Key Vault
        client.Scope = Scope.Parse("catalog:read");
    });

// Named HttpClient: token acquired, cached and attached automatically
builder.Services.AddClientCredentialsHttpClient(
    "catalog",
    ClientCredentialsClientName.Parse("catalog.client"),
    client => client.BaseAddress = new Uri("https://api.example.com/catalog/"));

builder.Services.AddHostedService<CatalogWorker>();

await builder.Build().RunAsync();
```

```csharp
public sealed class CatalogWorker(IHttpClientFactory factory, ILogger<CatalogWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            // ✅ no token code: acquired, cached and refreshed transparently
            var client = factory.CreateClient("catalog");
            var response = await client.GetAsync("items", stoppingToken);
            logger.LogInformation("Catalog responded {Status}", response.StatusCode);

            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}
```

## Why this is the right shape
- **Strongly typed values (v4):** `ClientId`, `ClientSecret`, `Scope`, `Uri` for `TokenEndpoint`, and `ClientCredentialsClientName`.
- **Caching:** v4 uses `HybridCache` (in-memory by default), so no `AddDistributedMemoryCache()` is needed. Tokens are cached for their lifetime minus `CacheLifetimeBuffer` (60 s by default). Don't cache tokens yourself in fields.
- **Resiliency:** `AddClientCredentialsHttpClient` adds a handler that retries once on `401` (token expiry, DPoP nonce). If you used `AddHttpClient(...).AddClientCredentialsTokenHandler(...)` directly you would add `.AddDefaultAccessTokenResiliency()` yourself.
- **Secret:** the sample uses configuration rather than a literal. Since your project file also references the OIDC package, it's only needed if the app also has users.
