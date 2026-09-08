# Testing a BFF Application's /bff/user and Local API Endpoints

A BFF (Backend-for-Frontend) authenticates the browser with a session cookie, so integration tests need a cookie-aware `HttpClient`. Use a `CookieContainer` with an `HttpClientHandler`, and turn off automatic redirects so you can inspect the actual status codes instead of following redirects to the login page.

## Cookie-aware client

```csharp
using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;

public class BffTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public BffTests(WebApplicationFactory<Program> factory)
    {
        var cookies = new CookieContainer();
        var handler = new HttpClientHandler
        {
            CookieContainer = cookies,
            AllowAutoRedirect = false   // don't follow the 302 to the IdP
        };
        _client = factory.CreateDefaultClient(handler);
    }

    [Fact]
    public async Task UserEndpoint_WithoutSession_Returns401()
    {
        var response = await _client.GetAsync("/bff/user");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```

Without a login, there's no session cookie, so `/bff/user` returns `401 Unauthorized` rather than redirecting.

## Antiforgery on local API routes

BFF local/proxied API routes are protected against CSRF, so calls from JavaScript must include an antiforgery header. In tests, a request that omits it should be rejected.

```csharp
[Fact]
public async Task LocalApi_WithoutAntiforgeryHeader_IsRejected()
{
    var response = await _client.GetAsync("/api/data");

    // Missing antiforgery protection => request is rejected as unauthorized
    Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
}

[Fact]
public async Task LocalApi_WithAntiforgeryHeader_IsAccepted()
{
    // Provide an antiforgery header so the CSRF check passes
    _client.DefaultRequestHeaders.Add("X-Requested-With", "XMLHttpRequest");

    var response = await _client.GetAsync("/api/data");

    Assert.NotEqual(HttpStatusCode.Unauthorized, response.StatusCode);
}
```

## Notes
- Cookie handling via `CookieContainer` is essential so that, once you simulate a login, the session cookie flows to subsequent requests.
- `AllowAutoRedirect = false` lets you assert on `401`/`302` directly.
- The BFF endpoints protect against CSRF; make sure your test sends whatever antiforgery header your BFF configuration requires (check your BFF setup for the exact header name and value).
