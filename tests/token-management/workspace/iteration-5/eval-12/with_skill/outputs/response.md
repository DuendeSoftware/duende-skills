# Minimal Client Credentials Setup (v4)

```csharp
using Duende.AccessTokenManagement;

var builder = Host.CreateApplicationBuilder(args);

// 1. Register the named client credentials client
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.company.com/connect/token");
        client.ClientId = ClientId.Parse("worker-client");
        client.ClientSecret = ClientSecret.Parse("worker-secret");
        client.Scope = Scope.Parse("catalog:read");
    });

// 2. Register an HttpClient that attaches the token automatically
builder.Services.AddClientCredentialsHttpClient(
    "catalog",
    ClientCredentialsClientName.Parse("catalog.client"),
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.company.com/catalog/");
    });

builder.Services.AddHostedService<Worker>();

var host = builder.Build();
host.Run();
```

Use it — no token code required:

```csharp
public sealed class Worker(IHttpClientFactory factory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        var client = factory.CreateClient("catalog"); // token acquired, cached, attached
        var response = await client.GetAsync("items", ct);
        // ...
    }
}
```

That's the whole registration:

1. `AddClientCredentialsTokenManagement().AddClient(...)` — defines the client (token endpoint, id, secret, scope).
2. `AddClientCredentialsHttpClient(...)` — a named `HttpClient` that acquires, caches, refreshes, and attaches the token (and retries once on 401).

No `AddDistributedMemoryCache()` needed — v4 caches with `HybridCache` automatically.

> Typed-client alternative: `AddHttpClient<CatalogClient>(...).AddClientCredentialsTokenHandler(ClientCredentialsClientName.Parse("catalog.client"))` (add `.AddDefaultAccessTokenResiliency()` before the handler for 401 retries).
