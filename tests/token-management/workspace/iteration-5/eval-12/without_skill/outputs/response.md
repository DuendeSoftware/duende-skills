# Minimal Client Credentials Token Management

```csharp
var builder = Host.CreateApplicationBuilder(args);

// Register client credentials token management with a named client
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog", client =>
    {
        client.TokenEndpoint = "https://sts.company.com/connect/token";
        client.ClientId = "worker-client";
        client.ClientSecret = "worker-secret";
        client.Scope = "catalog:read";
    });

// Register an HttpClient that automatically gets and attaches the token
builder.Services.AddClientCredentialsHttpClient("catalog-client", "catalog", client =>
{
    client.BaseAddress = new Uri("https://api.company.com/catalog/");
});

builder.Services.AddHostedService<Worker>();

var host = builder.Build();
host.Run();
```

Then just resolve and use the client:

```csharp
public class Worker : BackgroundService
{
    private readonly IHttpClientFactory _factory;
    public Worker(IHttpClientFactory factory) => _factory = factory;

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        var client = _factory.CreateClient("catalog-client");
        var response = await client.GetAsync("items", ct);
        // ...
    }
}
```

That's it:

- `AddClientCredentialsTokenManagement().AddClient(...)` registers a client with the token endpoint, client id/secret, and scope.
- `AddClientCredentialsHttpClient(...)` gives you a named `HttpClient` whose handler fetches, caches, and attaches the access token automatically (renewing it when it expires).

No manual token requests or bearer-header code needed anywhere in your worker.
