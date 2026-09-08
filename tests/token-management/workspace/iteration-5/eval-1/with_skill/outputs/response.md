# Client Credentials Token Management for a Worker Service

Here's a complete setup for a .NET 10 worker service that calls the catalog API using client credentials. `Duende.AccessTokenManagement` will acquire, cache, refresh, and attach the token automatically — no manual token code at the call site.

## 1. Package

```bash
dotnet add package Duende.AccessTokenManagement
```

## 2. `Program.cs`

```csharp
using Duende.AccessTokenManagement;

var builder = Host.CreateApplicationBuilder(args);

// ✅ Register the named client credentials client (v4 strongly-typed setters)
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId     = ClientId.Parse("catalog-worker");
        client.ClientSecret = ClientSecret.Parse("worker-secret");
        client.Scope        = Scope.Parse("catalog:read");
    });

// ✅ Register a named HttpClient that automatically attaches the client credentials token.
//    AddClientCredentialsHttpClient also wires up the resiliency handler
//    (retries once on 401 for token expiry / DPoP nonce challenges).
builder.Services.AddClientCredentialsHttpClient(
    "catalog",
    ClientCredentialsClientName.Parse("catalog.client"),
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/catalog/");
    });

builder.Services.AddHostedService<CatalogWorker>();

var host = builder.Build();
host.Run();
```

## 3. The `BackgroundService`

```csharp
public sealed class CatalogWorker(
    IHttpClientFactory httpClientFactory,
    ILogger<CatalogWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            // ✅ Token acquired, cached, and refreshed transparently by the library.
            //    No GetAccessTokenAsync / SetBearerToken code needed here.
            var client = httpClientFactory.CreateClient("catalog");

            var response = await client.GetAsync("items", stoppingToken);
            response.EnsureSuccessStatusCode();

            var content = await response.Content.ReadAsStringAsync(stoppingToken);
            logger.LogInformation("Catalog response: {Content}", content);

            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}
```

## Why this works

- **`AddClientCredentialsTokenManagement().AddClient(...)`** registers the token-management services and defines the `catalog.client` credential set.
- **`AddClientCredentialsHttpClient(...)`** binds an `HttpClient` named `catalog` to that client. Every request it makes gets a valid bearer token attached automatically, served from the cache (v4 uses `HybridCache` — no `AddDistributedMemoryCache()` required).
- **`ClientCredentialsClientName.Parse("catalog.client")`** uses the v4 strongly-typed client name rather than a raw string.
- The worker just calls `factory.CreateClient("catalog")` and issues requests — the library owns the token lifecycle, so you never store tokens in fields or static variables.

If you'd rather use a typed client, swap the named registration for:

```csharp
builder.Services.AddHttpClient<CatalogClient>(client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/catalog/");
    })
    .AddClientCredentialsTokenHandler(ClientCredentialsClientName.Parse("catalog.client"));
```

(When using `AddClientCredentialsTokenHandler` directly, add `.AddDefaultAccessTokenResiliency()` before it to retry once on 401.)
