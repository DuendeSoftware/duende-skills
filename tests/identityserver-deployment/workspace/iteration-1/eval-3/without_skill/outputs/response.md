# Adding Health Checks to IdentityServer

You can add health checks using ASP.NET Core's built-in health check framework.

## Implementation

```csharp
using Microsoft.Extensions.Diagnostics.HealthChecks;

public class IdentityServerHealthCheck : IHealthCheck
{
    private readonly HttpClient _httpClient;

    public IdentityServerHealthCheck(IHttpClientFactory httpClientFactory)
    {
        _httpClient = httpClientFactory.CreateClient();
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var discoveryResponse = await _httpClient.GetAsync(
                "https://localhost:5001/.well-known/openid-configuration",
                cancellationToken);

            if (discoveryResponse.IsSuccessStatusCode)
            {
                var jwksResponse = await _httpClient.GetAsync(
                    "https://localhost:5001/.well-known/openid-configuration/jwks",
                    cancellationToken);

                if (jwksResponse.IsSuccessStatusCode)
                    return HealthCheckResult.Healthy();
            }

            return HealthCheckResult.Unhealthy("Discovery or JWKS endpoint failed");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Health check failed", ex);
        }
    }
}
```

## Registration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient();

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

builder.Services.AddHealthChecks()
    .AddCheck<IdentityServerHealthCheck>("identityserver");

var app = builder.Build();

app.UseIdentityServer();
app.MapHealthChecks("/health");

app.Run();
```

This makes an HTTP request to the discovery and JWKS endpoints to verify they're working.
