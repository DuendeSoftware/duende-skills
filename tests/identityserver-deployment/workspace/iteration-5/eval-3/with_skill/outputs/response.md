# Health checks for IdentityServer discovery + JWKS endpoints

The most reliable way to health-check IdentityServer internally is to resolve the registered endpoint handlers from DI and invoke them directly — no outbound HTTP call, no dependency on the load balancer or network. IdentityServer registers each protocol endpoint as a `Hosting.Endpoint`, and you can look them up by name (requires IdentityServer v6.3+).

## Discovery endpoint health check

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Endpoints.Results;
using Duende.IdentityServer.Hosting;
using Microsoft.Extensions.Diagnostics.HealthChecks;

public class DiscoveryHealthCheck : IHealthCheck
{
    private readonly IEnumerable<Hosting.Endpoint> _endpoints;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public DiscoveryHealthCheck(IEnumerable<Hosting.Endpoint> endpoints,
        IHttpContextAccessor httpContextAccessor)
    {
        _endpoints = endpoints;
        _httpContextAccessor = httpContextAccessor;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var endpoint = _endpoints.FirstOrDefault(
                x => x.Name == IdentityServerConstants.EndpointNames.Discovery);
            if (endpoint != null)
            {
                var handler = _httpContextAccessor.HttpContext!.RequestServices
                    .GetRequiredService(endpoint.Handler) as IEndpointHandler;
                if (handler != null)
                {
                    var result = await handler.ProcessAsync(
                        _httpContextAccessor.HttpContext);
                    if (result is DiscoveryDocumentResult)
                    {
                        return HealthCheckResult.Healthy();
                    }
                }
            }
        }
        catch { }

        return new HealthCheckResult(context.Registration.FailureStatus);
    }
}
```

## JWKS endpoint health check

This verifies IdentityServer can access its signing keys:

```csharp
public class DiscoveryKeysHealthCheck : IHealthCheck
{
    private readonly IEnumerable<Hosting.Endpoint> _endpoints;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public DiscoveryKeysHealthCheck(IEnumerable<Hosting.Endpoint> endpoints,
        IHttpContextAccessor httpContextAccessor)
    {
        _endpoints = endpoints;
        _httpContextAccessor = httpContextAccessor;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var endpoint = _endpoints.FirstOrDefault(
                x => x.Name == IdentityServerConstants.EndpointNames.Jwks);
            if (endpoint != null)
            {
                var handler = _httpContextAccessor.HttpContext!.RequestServices
                    .GetRequiredService(endpoint.Handler) as IEndpointHandler;
                if (handler != null)
                {
                    var result = await handler.ProcessAsync(
                        _httpContextAccessor.HttpContext);
                    if (result is JsonWebKeysResult)
                    {
                        return HealthCheckResult.Healthy();
                    }
                }
            }
        }
        catch { }

        return new HealthCheckResult(context.Registration.FailureStatus);
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

// IHttpContextAccessor is required by the health checks
builder.Services.AddHttpContextAccessor();

builder.Services.AddHealthChecks()
    .AddCheck<DiscoveryHealthCheck>("discovery")
    .AddCheck<DiscoveryKeysHealthCheck>("jwks");

var app = builder.Build();

app.UseIdentityServer();

app.MapHealthChecks("/health");

app.Run();
```

## Why this approach

- **`IEnumerable<Hosting.Endpoint>`** is injected so you can find the registered protocol endpoints by name (`IdentityServerConstants.EndpointNames.Discovery` / `.Jwks`).
- **`IHttpContextAccessor`** is injected so the handler runs with the real request-scoped services and produces a real result.
- Checking the returned result type (`DiscoveryDocumentResult` / `JsonWebKeysResult`) confirms the endpoint actually produced a valid response — for JWKS that means signing keys are reachable, which is a strong signal your config/operational store and Data Protection are healthy.

Your monitoring system hitting `GET /health` will now get `200 Healthy` only when both the discovery and JWKS endpoints are functioning. Finding endpoints by name requires IdentityServer v6.3+.
