# Testing BFF Endpoints: /bff/user and Antiforgery

Here's how to test Duende BFF endpoints using cookie-based session simulation with `CookieContainer` and the `x-csrf` antiforgery header.

## 1. BFF WebApplicationFactory

```csharp
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

public sealed class BffFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            // Replace OIDC with a short-circuit test handler
            // that bypasses the external redirect in tests
            services.Configure<OpenIdConnectOptions>("oidc", options =>
            {
                options.Events.OnRedirectToIdentityProvider = ctx =>
                {
                    ctx.HandleResponse();
                    return Task.CompletedTask;
                };
            });
        });
    }
}
```

## 2. BFF Endpoint Tests with Cookie Simulation

```csharp
using System.Net;
using Xunit;

public class BffUserEndpointTests : IClassFixture<BffFactory>
{
    private readonly HttpClient _client;

    public BffUserEndpointTests(BffFactory factory)
    {
        // Use CookieContainer so session cookies are stored and sent automatically
        var cookieContainer = new CookieContainer();
        var handler = new HttpClientHandler
        {
            CookieContainer = cookieContainer,
            AllowAutoRedirect = false  // Don't follow redirects — we want to see 401/302
        };
        _client = factory.CreateDefaultClient(handler);
    }

    [Fact]
    public async Task UserEndpoint_WithoutSession_ShouldReturn401()
    {
        // No prior login — no session cookie
        var response = await _client.GetAsync("/bff/user");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task LocalApiEndpoint_WithoutAntiforgeryHeader_ShouldReturn400()
    {
        // Missing the x-csrf: 1 header — BFF rejects the request
        var response = await _client.GetAsync("/api/data");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task LocalApiEndpoint_WithAntiforgeryHeader_ShouldNotReturn400()
    {
        // Include the required x-csrf: 1 header
        _client.DefaultRequestHeaders.Add("x-csrf", "1");

        var response = await _client.GetAsync("/api/data");

        // Without a session, this returns 401 (not 400) — the antiforgery check passes
        Assert.NotEqual(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
```

Key points:
- `CookieContainer` and `HttpClientHandler` with `AllowAutoRedirect = false` are used for cookie-based session simulation.
- `/bff/user` returns `401 Unauthorized` when there is no session cookie.
- Local API routes return `400 BadRequest` when the `x-csrf` header is missing.
- Including `x-csrf: 1` satisfies the antiforgery check — the request proceeds to authentication/authorization instead of being rejected.
