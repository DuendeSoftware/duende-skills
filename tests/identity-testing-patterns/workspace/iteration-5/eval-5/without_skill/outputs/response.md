# Testing the AdminOnly Policy on DELETE /api/products/{id}

Your `DELETE /api/products/{id}` endpoint uses `[Authorize(Policy = "AdminOnly")]`, and the policy requires `role=admin`. With a test authentication handler you can inject different claim sets per test and verify the three outcomes (204 / 403 / 401) while keeping the real policy running.

## Test auth handler with a per-test claims provider

```csharp
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

public interface ITestClaimsProvider { IEnumerable<Claim>? GetClaims(); }

public class TestClaimsProvider : ITestClaimsProvider
{
    private IEnumerable<Claim>? _claims;
    public void SetClaims(IEnumerable<Claim> claims) => _claims = claims;
    public void ClearClaims() => _claims = null;
    public IEnumerable<Claim>? GetClaims() => _claims;
}

public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string SchemeName = "Test";
    private readonly ITestClaimsProvider _provider;

    public TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger, UrlEncoder encoder, ITestClaimsProvider provider)
        : base(options, logger, encoder) => _provider = provider;

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = _provider.GetClaims();
        if (claims is null)
            return Task.FromResult(AuthenticateResult.NoResult());

        var identity = new ClaimsIdentity(claims, SchemeName);
        var ticket = new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

## Factory

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

public class ApiFactory : WebApplicationFactory<Program>
{
    public TestClaimsProvider ClaimsProvider { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddSingleton<ITestClaimsProvider>(ClaimsProvider);
            services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                    TestAuthHandler.SchemeName, _ => { });
        });
    }
}
```

## Tests: 204 / 403 / 401

```csharp
using System.Net;
using System.Security.Claims;

public class AdminOnlyTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public AdminOnlyTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Admin_Delete_Returns204()
    {
        _factory.ClaimsProvider.SetClaims(new[]
        {
            new Claim("role", "admin")
        });

        var response = await _client.DeleteAsync("/api/products/5");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task Viewer_Delete_Returns403()
    {
        _factory.ClaimsProvider.SetClaims(new[]
        {
            new Claim("role", "viewer")
        });

        var response = await _client.DeleteAsync("/api/products/5");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task NoAuth_Delete_Returns401()
    {
        _factory.ClaimsProvider.ClearClaims();

        var response = await _client.DeleteAsync("/api/products/5");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```

## Why it works
- **Admin** → policy satisfied → the handler returns `NoContent` (204).
- **Viewer** → authenticated but the `AdminOnly` requirement fails → 403.
- **No claims** → `NoResult()` → the `[Authorize]` attribute challenges → 401.
- `IClassFixture<ApiFactory>` shares one factory instance across all tests in the class; each test sets its own distinct claim set (or clears it) beforehand.
