# Health Checks for IdentityServer

## Implementation

Here are two health check classes that verify the discovery and JWKS endpoints are working by directly invoking the IdentityServer endpoint handlers.

### DiscoveryHealthCheck

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
                var handler = _httpContextAccessor.HttpContext.RequestServices
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

### DiscoveryKeysHealthCheck (JWKS)

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
                var handler = _httpContextAccessor.HttpContext.RequestServices
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

### Registration in Program.cs

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpContextAccessor();

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

// Register health checks
builder.Services.AddHealthChecks()
    .AddCheck<DiscoveryHealthCheck>("discovery")
    .AddCheck<DiscoveryKeysHealthCheck>("jwks");

var app = builder.Build();

app.UseIdentityServer();

// Map health endpoint
app.MapHealthChecks("/health");

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

**Note**: Finding endpoints by name requires IdentityServer v6.3+. Both health check classes inject `IEnumerable<Hosting.Endpoint>` and `IHttpContextAccessor` to locate and invoke the endpoint handlers directly.
