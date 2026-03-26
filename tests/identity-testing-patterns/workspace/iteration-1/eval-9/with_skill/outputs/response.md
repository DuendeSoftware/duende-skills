# Testing BFF Endpoints

## BFF Factory

```csharp
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.Extensions.DependencyInjection;

public sealed class BffFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            // Bypass OIDC redirect in tests
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

## Tests with Cookie Session Simulation

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
            AllowAutoRedirect = false
        };
        _client = factory.CreateDefaultClient(handler);
    }

    [Fact]
    public async Task UserEndpoint_WithoutSession_ShouldReturn401()
    {
        // No prior login — no session cookie
        var response = await _client.GetAsync("/bff/user");

        // BFF returns 401 Unauthorized when there's no active session
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task LocalApi_WithoutAntiforgeryHeader_ShouldReturn400()
    {
        // No x-csrf header — BFF rejects the request
        var response = await _client.GetAsync("/api/data");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task LocalApi_WithAntiforgeryHeader_ShouldNotReturn400()
    {
        // Include the x-csrf: 1 header
        _client.DefaultRequestHeaders.Add("x-csrf", "1");

        var response = await _client.GetAsync("/api/data");

        // Without a session this returns 401 (not 400), because the antiforgery check passes
        Assert.NotEqual(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
```

## How BFF Antiforgery Works

1. BFF local API endpoints require the `x-csrf: 1` header on every request
2. If the header is missing, BFF returns `400 Bad Request` before reaching the API handler
3. If the header is present but there's no session, the request passes antiforgery but returns `401 Unauthorized`
4. `AllowAutoRedirect = false` prevents the test client from following 302 redirects to the identity provider, which would mask the actual status code
5. `CookieContainer` stores session cookies between requests, simulating a browser session
