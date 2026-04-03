# Health Checks for IdentityServer

## Solution

You can add ASP.NET Core health checks that make HTTP requests to the discovery and JWKS endpoints.

```csharp
using Microsoft.Extensions.Diagnostics.HealthChecks;

public class DiscoveryHealthCheck : IHealthCheck
{
    private readonly IHttpClientFactory _httpClientFactory;

    public DiscoveryHealthCheck(IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var client = _httpClientFactory.CreateClient();
            var response = await client.GetAsync(
                "https://localhost/.well-known/openid-configuration", cancellationToken);
            if (response.IsSuccessStatusCode)
                return HealthCheckResult.Healthy();
        }
        catch { }

        return HealthCheckResult.Unhealthy("Discovery endpoint is not responding");
    }
}

public class JwksHealthCheck : IHealthCheck
{
    private readonly IHttpClientFactory _httpClientFactory;

    public JwksHealthCheck(IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var client = _httpClientFactory.CreateClient();
            var response = await client.GetAsync(
                "https://localhost/.well-known/openid-configuration/jwks", cancellationToken);
            if (response.IsSuccessStatusCode)
                return HealthCheckResult.Healthy();
        }
        catch { }

        return HealthCheckResult.Unhealthy("JWKS endpoint is not responding");
    }
}
```

### Registration in Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient();

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

builder.Services.AddHealthChecks()
    .AddCheck<DiscoveryHealthCheck>("discovery")
    .AddCheck<JwksHealthCheck>("jwks");

var app = builder.Build();

app.UseIdentityServer();
app.MapHealthChecks("/health");

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This uses `IHttpClientFactory` to make HTTP requests to the endpoints. The health checks will report unhealthy if the endpoints don't respond with a success status code.
