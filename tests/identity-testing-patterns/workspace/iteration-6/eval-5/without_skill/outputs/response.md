# AdminOnly policy tests with TestAuthHandler

## Handler (claims come from a header; no header = unauthenticated)
```csharp
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string Scheme = "Test";
    public const string RoleHeader = "X-Test-Role";

    public TestAuthHandler(IOptionsMonitor<AuthenticationSchemeOptions> o, ILoggerFactory l, UrlEncoder e)
        : base(o, l, e) { }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue(RoleHeader, out var role))
            return Task.FromResult(AuthenticateResult.NoResult());

        var identity = new ClaimsIdentity(new[]
        {
            new Claim("sub", "test-user"),
            new Claim("role", role.ToString())
        }, Scheme, "sub", "role");

        return Task.FromResult(AuthenticateResult.Success(
            new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme)));
    }
}
```

## Factory
```csharp
public class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddAuthentication(o =>
            {
                o.DefaultScheme = TestAuthHandler.Scheme;
                o.DefaultAuthenticateScheme = TestAuthHandler.Scheme;
                o.DefaultChallengeScheme = TestAuthHandler.Scheme;
            }).AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.Scheme, _ => { });
        });
    }
}
```

## Tests
```csharp
using System.Net;

public class AdminPolicyTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    public AdminPolicyTests(ApiFactory factory) => _factory = factory;

    private HttpClient ClientWithRole(string? role)
    {
        var client = _factory.CreateClient();
        if (role is not null)
            client.DefaultRequestHeaders.Add(TestAuthHandler.RoleHeader, role);
        return client;
    }

    [Fact]
    public async Task Admin_gets_204()
    {
        var response = await ClientWithRole("admin").DeleteAsync("/api/products/1");
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task Viewer_gets_403()
    {
        var response = await ClientWithRole("viewer").DeleteAsync("/api/products/1");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Anonymous_gets_401()
    {
        var response = await ClientWithRole(null).DeleteAsync("/api/products/1");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```

Why: no header → `NoResult` → challenge → 401; authenticated "viewer" fails `RequireClaim("role","admin")` → forbid → 403; admin passes → minimal API returns `NoContent` → 204. `ConfigureTestServices` runs after the app's registrations so the test scheme overrides the defaults.
