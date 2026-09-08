# Testing a Duende BFF: /bff/user 401 and Antiforgery-Protected Local APIs

BFF tests need **cookie-based session simulation** because the user's identity lives in a session cookie, not a bearer token. Use a `CookieContainer` + `HttpClientHandler` with `AllowAutoRedirect = false` so login redirects don't swallow the status codes you want to assert. The BFF also enforces antiforgery on local API routes via the `x-csrf: 1` header — omitting it returns `400`.

## The BFF test factory

```csharp
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

public sealed class BffFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            // Bypass the external IdP redirect in tests
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

## Cookie-aware client + tests

```csharp
using System.Net;

public class BffEndpointTests : IClassFixture<BffFactory>
{
    private readonly HttpClient _client;

    public BffEndpointTests(BffFactory factory)
    {
        // ✅ CookieContainer stores/sends the session cookie;
        //    AllowAutoRedirect = false keeps 302s from masking real status codes
        var cookies = new CookieContainer();
        var handler = new HttpClientHandler
        {
            CookieContainer = cookies,
            AllowAutoRedirect = false
        };
        _client = factory.CreateDefaultClient(handler);
    }

    [Fact]
    public async Task UserEndpoint_WithoutSession_Returns401()
    {
        // No prior login => no session cookie
        var response = await _client.GetAsync("/bff/user");

        // BFF returns 401 (not a redirect) for the management user endpoint
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task LocalApi_WithoutAntiforgeryHeader_Returns400()
    {
        // ❌ Missing the x-csrf: 1 header
        var response = await _client.GetAsync("/api/data");

        // BFF antiforgery middleware rejects the call before auth
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task LocalApi_WithAntiforgeryHeader_PassesCsrfCheck()
    {
        // ✅ Include the required antiforgery header
        _client.DefaultRequestHeaders.Add("x-csrf", "1");

        var response = await _client.GetAsync("/api/data");

        // The antiforgery check now passes; without a session this is 401,
        // but it is no longer the 400 antiforgery rejection.
        Assert.NotEqual(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
```

## Why these outcomes
- **`/bff/user` → 401 without a session.** The BFF user endpoint is designed to return `401 Unauthorized` (rather than redirecting to the IdP) when there is no authenticated session, which makes it testable with a plain `HttpClient`.
- **Local API `→ 400` without `x-csrf: 1`.** Duende BFF protects proxied/local API routes with an antiforgery header requirement. If the `x-csrf: 1` header is missing, the request is rejected with `400 Bad Request` before authorization even runs — so adding the header is what lets the request proceed.
- **`AllowAutoRedirect = false`** ensures you observe the real status codes instead of the client silently following a `302` to the login page.
