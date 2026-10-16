# Testing a Duende BFF: `/bff/user` → 401 and missing antiforgery header → 400

BFF tests need a `WebApplicationFactory` with a cookie-aware client. Key rules:
- Use a `CookieContainer` so session cookies are stored/sent automatically.
- Set `AllowAutoRedirect = false` so redirects (e.g. to the IdP) don't swallow the status code you want to assert.
- BFF local API calls must carry `x-csrf: 1`; **without it the response is 400**.
- Override the OIDC `OnRedirectToIdentityProvider` event so tests never try to reach an external IdP.

## Factory
```csharp
public sealed class BffFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.Configure<OpenIdConnectOptions>("oidc", options =>
            {
                options.Events.OnRedirectToIdentityProvider = ctx =>
                {
                    // Bypass the external redirect in tests
                    ctx.HandleResponse();
                    return Task.CompletedTask;
                };
            });
        });
    }
}
```

## Tests
```csharp
public class BffUserEndpointTests : IClassFixture<BffFactory>
{
    private readonly BffFactory _factory;

    public BffUserEndpointTests(BffFactory factory) => _factory = factory;

    // Fresh cookie-aware, non-redirecting client per test (no shared headers/cookies)
    private HttpClient CreateClient()
    {
        var handler = new HttpClientHandler
        {
            CookieContainer = new CookieContainer(),
            AllowAutoRedirect = false
        };
        return _factory.CreateDefaultClient(handler);
    }

    [Fact]
    public async Task UserEndpoint_WithoutSession_ShouldReturn401()
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Add("x-csrf", "1");   // management endpoints expect the header too

        var response = await client.GetAsync("/bff/user");

        // 401, not a 302 redirect to login
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task LocalApi_WithoutAntiForgeryHeader_ShouldReturn400()
    {
        var client = CreateClient();      // ❌ no x-csrf header

        var response = await client.GetAsync("/api/data");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task LocalApi_WithAntiForgeryHeader_ShouldPassCsrfCheck()
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Add("x-csrf", "1");

        var response = await client.GetAsync("/api/data");

        // No session so this is 401, but the antiforgery check itself passed
        Assert.NotEqual(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
```

Notes:
- Replace `/api/data` with one of your actual BFF-protected local routes.
- Ensure the BFF host exposes `public partial class Program { }`.
- Each test builds its own client so a header added in one test (e.g. `x-csrf`) can't leak into the 400-expectation test.
- For authenticated scenarios, simulate a session (sign a test user into the cookie scheme or swap in a test auth handler) rather than running the real OIDC flow.
