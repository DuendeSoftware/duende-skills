# Minimal Client Credentials Setup with Duende.AccessTokenManagement

Here's the simplest setup for a .NET 9 worker service:

```bash
dotnet add package Duende.AccessTokenManagement
```

## Program.cs

```csharp
var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("api-client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("my-service");
        client.ClientSecret = ClientSecret.Parse("my-secret");
        client.Scope = Scope.Parse("api1");
    });

builder.Services.AddClientCredentialsHttpClient(
    "api",
    ClientCredentialsClientName.Parse("api-client"),
    client => client.BaseAddress = new Uri("https://api.example.com/"));

builder.Services.AddHostedService<Worker>();

var host = builder.Build();
host.Run();
```

## Worker.cs

```csharp
public sealed class Worker(IHttpClientFactory factory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            var client = factory.CreateClient("api");
            var response = await client.GetAsync("data", ct);
            // ...
            await Task.Delay(TimeSpan.FromMinutes(1), ct);
        }
    }
}
```

The library handles token acquisition, caching, and automatic refresh transparently.
