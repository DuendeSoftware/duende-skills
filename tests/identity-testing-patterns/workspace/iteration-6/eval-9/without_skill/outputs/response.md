# Testing Duende BFF: /bff/user 401 and antiforgery 400

The Duende BFF (v3/v4):
- `/bff/user` returns **401** without a session when the `X-CSRF: 1` header is provided (the management endpoints require the anti-forgery header; without it you may get 401 too in newer versions, so always send it for the "no session" test).
- Local APIs mapped with `.AsBffApiEndpoint()` / `MapRemoteBffApiEndpoint` require `X-CSRF: 1`; when missing, the response is **400 Bad Request**.

## Factory
```csharp
public class BffFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureTestServices(services =>
        {
            // avoid contacting a real OIDC provider
            services.PostConfigure<OpenIdConnectOptions>("oidc", o =>
            {
                o.Configuration = new OpenIdConnectConfiguration
                {
                    Issuer = "https://idp.test",
                    AuthorizationEndpoint = "https://idp.test/connect/authorize",
                    TokenEndpoint = "https://idp.test/connect/token"
                };
                o.ConfigurationManager = null;
            });
        });
    }

    // Don't follow redirects: an unauthenticated browser route would redirect to the IdP
    protected override void ConfigureClient(HttpClient client) { }

    public HttpClient CreateNoRedirectClient() =>
        CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false, HandleCookies = true });
}
```

## Tests
```csharp
public class BffTests : IClassFixture<BffFactory>
{
    private readonly BffFactory _factory;
    public BffTests(BffFactory f) => _factory = f;

    [Fact]
    public async Task User_endpoint_returns_401_without_session()
    {
        var client = _factory.CreateNoRedirectClient();
        var request = new HttpRequestMessage(HttpMethod.Get, "/bff/user");
        request.Headers.Add("X-CSRF", "1");

        var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Local_api_without_antiforgery_header_returns_400()
    {
        var client = _factory.CreateNoRedirectClient();
        var response = await client.GetAsync("/local/data");   // your local API route, no X-CSRF
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Local_api_with_header_but_no_session_returns_401()
    {
        var client = _factory.CreateNoRedirectClient();
        var request = new HttpRequestMessage(HttpMethod.Get, "/local/data");
        request.Headers.Add("X-CSRF", "1");
        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```
Notes: set `AllowAutoRedirect = false` so a login redirect (302) isn't followed into a 404 from the fake IdP. For authenticated scenarios, replace the cookie scheme with a test auth handler (as for APIs) instead of running the OIDC flow. The Program must expose `public partial class Program`.
