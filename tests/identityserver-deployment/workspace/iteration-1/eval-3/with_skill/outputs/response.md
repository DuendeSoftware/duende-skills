# Implementing Health Checks for IdentityServer

Here's how to add health checks that verify the discovery endpoint and JWKS endpoint are functioning correctly.

## Health Check Implementations

### Discovery Endpoint Health Check

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Endpoints.Results;
using Duende.IdentityServer.Hosting;
using Microsoft.Extensions.Diagnostics.HealthChecks;

public class DiscoveryHealthCheck : IHealthCheck
{
    private readonly IEnumerable<Hosting.Endpoint> _endpoints;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public DiscoveryHealthCheck(
        IEnumerable<Hosting.Endpoint> endpoints,
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

### JWKS Endpoint Health Check

```csharp
public class DiscoveryKeysHealthCheck : IHealthCheck
{
    private readonly IEnumerable<Hosting.Endpoint> _endpoints;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public DiscoveryKeysHealthCheck(
        IEnumerable<Hosting.Endpoint> endpoints,
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

## Registration in Program.cs

```csharp
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

// Map the health endpoint
app.MapHealthChecks("/health");

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## How It Works

Both health checks use the same pattern:

1. **Inject `IEnumerable<Hosting.Endpoint>`** — IdentityServer registers its internal endpoints in DI
2. **Inject `IHttpContextAccessor`** — needed to get the current HTTP context for handler invocation
3. **Find the endpoint by name** — using `IdentityServerConstants.EndpointNames.Discovery` and `.Jwks`
4. **Resolve and invoke the handler** — calls `ProcessAsync` to actually exercise the endpoint logic
5. **Check the result type** — `DiscoveryDocumentResult` for discovery, `JsonWebKeysResult` for JWKS

This approach tests the actual IdentityServer processing pipeline, including configuration store connectivity and signing key availability, rather than just checking if the HTTP endpoint responds.

**Note**: This endpoint name lookup requires IdentityServer v6.3+.
