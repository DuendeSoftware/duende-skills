# Adding Health Checks to IdentityServer

## Overview

You can use ASP.NET Core's built-in health check framework to verify that your IdentityServer endpoints are working. We'll create health checks that verify the discovery and JWKS endpoints are accessible.

## Step 1: Create the Health Checks

### Discovery Endpoint Health Check

```csharp
using Microsoft.Extensions.Diagnostics.HealthChecks;

public class DiscoveryEndpointHealthCheck : IHealthCheck
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _configuration;

    public DiscoveryEndpointHealthCheck(
        IHttpClientFactory httpClientFactory,
        IConfiguration configuration)
    {
        _httpClientFactory = httpClientFactory;
        _configuration = configuration;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var client = _httpClientFactory.CreateClient();
            var authority = _configuration["IdentityServer:Authority"]
                ?? "https://localhost:5001";
            var response = await client.GetAsync(
                $"{authority}/.well-known/openid-configuration",
                cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                return HealthCheckResult.Healthy("Discovery endpoint is accessible.");
            }

            return HealthCheckResult.Unhealthy(
                $"Discovery endpoint returned {response.StatusCode}");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Discovery endpoint check failed.", ex);
        }
    }
}
```

### JWKS Endpoint Health Check

```csharp
using Microsoft.Extensions.Diagnostics.HealthChecks;

public class JwksEndpointHealthCheck : IHealthCheck
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _configuration;

    public JwksEndpointHealthCheck(
        IHttpClientFactory httpClientFactory,
        IConfiguration configuration)
    {
        _httpClientFactory = httpClientFactory;
        _configuration = configuration;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var client = _httpClientFactory.CreateClient();
            var authority = _configuration["IdentityServer:Authority"]
                ?? "https://localhost:5001";
            var response = await client.GetAsync(
                $"{authority}/.well-known/openid-configuration/jwks",
                cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                return HealthCheckResult.Healthy("JWKS endpoint is accessible.");
            }

            return HealthCheckResult.Unhealthy(
                $"JWKS endpoint returned {response.StatusCode}");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("JWKS endpoint check failed.", ex);
        }
    }
}
```

## Step 2: Register in Program.cs

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient();

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

builder.Services.AddHealthChecks()
    .AddCheck<DiscoveryEndpointHealthCheck>("discovery")
    .AddCheck<JwksEndpointHealthCheck>("jwks");

var app = builder.Build();

app.UseIdentityServer();

app.MapHealthChecks("/health");

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This will expose a `/health` endpoint that returns HTTP 200 when both the discovery and JWKS endpoints are accessible and working.
