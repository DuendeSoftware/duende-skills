# Minimal Client Credentials Token Management Setup

Here's a minimal setup for client credentials token management in a .NET 9 worker service:

```csharp
// Program.cs
var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddDistributedMemoryCache();

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("my-client", client =>
    {
        client.TokenEndpoint = "https://sts.example.com/connect/token";
        client.ClientId = "my-service";
        client.ClientSecret = "my-secret";
        client.Scope = "api1";
    });

builder.Services.AddHttpClient("api", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/");
}).AddClientCredentialsTokenHandler("my-client");

builder.Services.AddHostedService<Worker>();

var host = builder.Build();
host.Run();
```

And the worker:

```csharp
public class Worker : BackgroundService
{
    private readonly IHttpClientFactory _factory;

    public Worker(IHttpClientFactory factory)
    {
        _factory = factory;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var client = _factory.CreateClient("api");
            var response = await client.GetAsync("data", stoppingToken);
            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}
```

The key steps are:
1. `AddDistributedMemoryCache()` — required for caching tokens
2. `AddClientCredentialsTokenManagement().AddClient()` — configure the token endpoint and credentials
3. `AddClientCredentialsTokenHandler()` on the HTTP client — automatically attaches the token

The library handles token acquisition, caching, and renewal transparently.
