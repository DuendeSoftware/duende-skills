# Minimal Client Credentials Token Management Setup

Here's the simplest possible setup for client credentials token management in a .NET 9 worker service using Duende.AccessTokenManagement v4:

```csharp
// Program.cs
var builder = Host.CreateApplicationBuilder(args);

// 1. Register token management with a named client
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("my.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("my-service");
        client.ClientSecret = ClientSecret.Parse("my-secret");
        client.Scope = Scope.Parse("api1");
    });

// 2. Register an HTTP client that automatically acquires and attaches the token
builder.Services.AddClientCredentialsHttpClient(
    "api",
    ClientCredentialsClientName.Parse("my.client"),
    client => client.BaseAddress = new Uri("https://api.example.com/"));

builder.Services.AddHostedService<Worker>();

var host = builder.Build();
host.Run();
```

That's it. Three steps:
1. `AddClientCredentialsTokenManagement()` registers the core services
2. `.AddClient()` defines the token endpoint, client credentials, and scope
3. `AddClientCredentialsHttpClient()` (or `.AddClientCredentialsTokenHandler()`) wires up an `HttpClient` that automatically acquires, caches, and attaches the token

Your worker just uses `IHttpClientFactory` — no token code needed:

```csharp
public class Worker(IHttpClientFactory factory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var client = factory.CreateClient("api");
            var response = await client.GetAsync("data", stoppingToken);
            // Token is already attached — no manual code
            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}
```

No `AddDistributedMemoryCache()` is needed — v4 uses `HybridCache` automatically for token caching.
