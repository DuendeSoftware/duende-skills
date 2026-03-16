# Implementing Health Checks for IdentityServer Discovery and JWKS Endpoints

## Overview

Rather than making external HTTP calls to the discovery and JWKS endpoints, we can invoke the internal IdentityServer endpoint handlers directly. This approach is more reliable (no network dependency), faster, and tests the actual processing pipeline including access to configuration and signing key stores.

## Step 1: Discovery Endpoint Health Check

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
                        _httpContextAccessor.HttpContext!);

                    if (result is DiscoveryDocumentResult)
                    {
                        return HealthCheckResult.Healthy(
                            "Discovery endpoint is responding correctly.");
                    }
                }
            }
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy(
                "Discovery endpoint check failed.", ex);
        }

        return new HealthCheckResult(
            context.Registration.FailureStatus,
            "Discovery endpoint handler not found or returned unexpected result.");
    }
}
```

## Step 2: JWKS Endpoint Health Check

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Endpoints.Results;
using Duende.IdentityServer.Hosting;
using Microsoft.Extensions.Diagnostics.HealthChecks;

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
                        _httpContextAccessor.HttpContext!);

                    if (result is JsonWebKeysResult)
                    {
                        return HealthCheckResult.Healthy(
                            "JWKS endpoint is responding correctly.");
                    }
                }
            }
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy(
                "JWKS endpoint check failed.", ex);
        }

        return new HealthCheckResult(
            context.Registration.FailureStatus,
            "JWKS endpoint handler not found or returned unexpected result.");
    }
}
```

## Step 3: Register Health Checks and Map Endpoint

Update your `Program.cs`:

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
    .AddCheck<DiscoveryHealthCheck>("discovery_endpoint")
    .AddCheck<DiscoveryKeysHealthCheck>("jwks_endpoint");

var app = builder.Build();

app.UseIdentityServer();

// Map health check endpoint
app.MapHealthChecks("/health");

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## How It Works

The pattern uses IdentityServer's internal `IEnumerable<Hosting.Endpoint>` collection, which contains all registered endpoint handlers. By looking up endpoints by their well-known names (`IdentityServerConstants.EndpointNames.Discovery` and `.Jwks`), we can:

1. Find the endpoint definition
2. Resolve the handler from the DI container
3. Invoke `ProcessAsync()` to execute the endpoint logic
4. Check the result type to confirm it completed successfully

This verifies the entire pipeline: configuration stores, signing key stores, and the endpoint processing logic — without making an external HTTP request.

**Note**: This pattern requires IdentityServer v6.3+ which added endpoint name constants.
