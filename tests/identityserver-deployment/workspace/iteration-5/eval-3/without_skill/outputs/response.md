# Health checks for the discovery and JWKS endpoints

ASP.NET Core has a built-in health checks system (`Microsoft.Extensions.Diagnostics.HealthChecks`). The most straightforward way to verify that your IdentityServer's discovery and JWKS endpoints are actually serving valid content is to write custom `IHealthCheck` implementations that request those endpoints and validate the responses.

## Install (optional URI helper)

```bash
dotnet add package AspNetCore.HealthChecks.Uris
```

The examples below use a plain `HttpClient`, so this package is optional.

## Custom health checks

```csharp
using System.Text.Json;
using Microsoft.Extensions.Diagnostics.HealthChecks;

public class DiscoveryHealthCheck : IHealthCheck
{
    private readonly IHttpClientFactory _httpClientFactory;

    public DiscoveryHealthCheck(IHttpClientFactory httpClientFactory)
        => _httpClientFactory = httpClientFactory;

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            var client = _httpClientFactory.CreateClient("self");
            var response = await client.GetAsync(
                "/.well-known/openid-configuration", cancellationToken);

            if (!response.IsSuccessStatusCode)
                return HealthCheckResult.Unhealthy("Discovery endpoint returned " + response.StatusCode);

            var json = await response.Content.ReadAsStringAsync(cancellationToken);
            using var doc = JsonDocument.Parse(json);

            // Basic sanity checks on the discovery document
            if (doc.RootElement.TryGetProperty("issuer", out _) &&
                doc.RootElement.TryGetProperty("jwks_uri", out _))
            {
                return HealthCheckResult.Healthy();
            }

            return HealthCheckResult.Unhealthy("Discovery document missing required fields");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Discovery endpoint failed", ex);
        }
    }
}

public class JwksHealthCheck : IHealthCheck
{
    private readonly IHttpClientFactory _httpClientFactory;

    public JwksHealthCheck(IHttpClientFactory httpClientFactory)
        => _httpClientFactory = httpClientFactory;

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            var client = _httpClientFactory.CreateClient("self");
            var response = await client.GetAsync(
                "/.well-known/openid-configuration/jwks", cancellationToken);

            if (!response.IsSuccessStatusCode)
                return HealthCheckResult.Unhealthy("JWKS endpoint returned " + response.StatusCode);

            var json = await response.Content.ReadAsStringAsync(cancellationToken);
            using var doc = JsonDocument.Parse(json);

            // Make sure at least one key is published
            if (doc.RootElement.TryGetProperty("keys", out var keys) &&
                keys.GetArrayLength() > 0)
            {
                return HealthCheckResult.Healthy();
            }

            return HealthCheckResult.Unhealthy("JWKS endpoint returned no keys");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("JWKS endpoint failed", ex);
        }
    }
}
```

## Register and map

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

// Named HttpClient pointing back at this server
builder.Services.AddHttpClient("self", c =>
{
    c.BaseAddress = new Uri("http://localhost:5000");
});

builder.Services.AddHealthChecks()
    .AddCheck<DiscoveryHealthCheck>("discovery")
    .AddCheck<JwksHealthCheck>("jwks");

var app = builder.Build();

app.UseIdentityServer();

app.MapHealthChecks("/health");

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Notes

- The discovery check confirms the well-known document is served and contains `issuer`/`jwks_uri`.
- The JWKS check confirms signing keys are published (`keys` array non-empty) — a good signal that signing key material and the key store are healthy.
- Your monitor hitting `GET /health` gets `200 Healthy` only when both endpoints respond correctly.
- For richer output you can add `AspNetCore.HealthChecks.UI` and expose a JSON response writer.
