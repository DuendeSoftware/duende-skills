# TestAuthHandler for integration tests

## 1. Test project packages
`Microsoft.AspNetCore.Mvc.Testing`, `xunit`, `Microsoft.NET.Test.Sdk`.

## 2. TestAuthHandler
Reads claims from a request header so each test controls the principal; no header means no auth (401).

```csharp
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string SchemeName = "Test";
    public const string ClaimsHeader = "X-Test-Claims";

    public TestAuthHandler(IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger, UrlEncoder encoder)
        : base(options, logger, encoder) { }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue(ClaimsHeader, out var header))
            return Task.FromResult(AuthenticateResult.NoResult());

        // format: "type=value;type=value"
        var claims = header.ToString()
            .Split(';', StringSplitOptions.RemoveEmptyEntries)
            .Select(p => p.Split('=', 2))
            .Select(p => new Claim(p[0], p[1]))
            .ToList();

        var identity = new ClaimsIdentity(claims, SchemeName, "name", "role");
        var ticket = new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

## 3. Factory
Replace the JWT scheme with the test scheme (same scheme name "Bearer" so `[Authorize]` and the default scheme keep working):

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;

public class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureTestServices(services =>
        {
            services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = TestAuthHandler.SchemeName;
                options.DefaultChallengeScheme = TestAuthHandler.SchemeName;
                options.DefaultScheme = TestAuthHandler.SchemeName;
            })
            .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, _ => { });
        });
    }

    public HttpClient CreateClientWithClaims(params (string Type, string Value)[] claims)
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Add(TestAuthHandler.ClaimsHeader,
            string.Join(';', claims.Select(c => $"{c.Type}={c.Value}")));
        return client;
    }
}
```

Note: because the endpoints use `[Authorize(Policy=...)]` without a scheme, they use the default scheme, which we override. The real JWT handler is still registered but unused, so no Authority call is made.

## 4. Tests
```csharp
using System.Net;

public class ProductsEndpointTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    public ProductsEndpointTests(ApiFactory factory) => _factory = factory;

    [Fact]
    public async Task No_credentials_returns_401()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Scope_api1_returns_200()
    {
        var client = _factory.CreateClientWithClaims(("sub", "1"), ("scope", "api1"));
        var response = await client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Authenticated_without_scope_returns_403()
    {
        var client = _factory.CreateClientWithClaims(("sub", "1"));
        var response = await client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Admin_role_can_delete()
    {
        var client = _factory.CreateClientWithClaims(("sub", "1"), ("role", "admin"));
        var response = await client.DeleteAsync("/api/products/1");
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }
}
```

Each test creates its own client with its own claims, so the principal is per-test. 401 occurs because the handler returns `NoResult`, so the challenge fires. 403 occurs when authenticated but the policy fails.
