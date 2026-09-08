# Integration Testing a Protected Web API with a Custom Test Auth Handler

A clean way to integration-test endpoints protected by `[Authorize]` is to replace the real JWT Bearer authentication with a lightweight test authentication handler. This lets you build a `ClaimsPrincipal` per test while keeping your authorization policies (`ApiScope`, `AdminOnly`) enforced. Unauthenticated requests will still return `401`.

## 1. TestAuthHandler

```csharp
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string SchemeName = "TestScheme";

    private readonly ITestClaimsProvider _claimsProvider;

    public TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder,
        ITestClaimsProvider claimsProvider)
        : base(options, logger, encoder)
    {
        _claimsProvider = claimsProvider;
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = _claimsProvider.GetClaims();

        // No claims => behave as an anonymous request so [Authorize] returns 401
        if (claims is null)
            return Task.FromResult(AuthenticateResult.NoResult());

        var identity = new ClaimsIdentity(claims, SchemeName);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

## 2. ITestClaimsProvider

A small provider lets each test control the identity:

```csharp
using System.Security.Claims;

public interface ITestClaimsProvider
{
    IEnumerable<Claim>? GetClaims();
}

public class TestClaimsProvider : ITestClaimsProvider
{
    private IEnumerable<Claim>? _claims;

    public void SetClaims(IEnumerable<Claim> claims) => _claims = claims;
    public void ClearClaims() => _claims = null;
    public IEnumerable<Claim>? GetClaims() => _claims;
}
```

## 3. WebApplicationFactory

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

public class TestApiFactory : WebApplicationFactory<Program>
{
    public TestClaimsProvider ClaimsProvider { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddSingleton<ITestClaimsProvider>(ClaimsProvider);

            services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                    TestAuthHandler.SchemeName, options => { });

            // Make the test scheme the default so [Authorize] uses it
            services.PostConfigure<AuthenticationOptions>(o =>
            {
                o.DefaultAuthenticateScheme = TestAuthHandler.SchemeName;
                o.DefaultChallengeScheme = TestAuthHandler.SchemeName;
            });
        });
    }
}
```

Note that authorization is left completely intact — the `ApiScope` and `AdminOnly` policies still run, so this only replaces *how the user is authenticated*, not *whether they are authorized*.

## 4. Tests

```csharp
using System.Net;
using System.Security.Claims;

public class ProductsTests : IClassFixture<TestApiFactory>
{
    private readonly TestApiFactory _factory;
    private readonly HttpClient _client;

    public ProductsTests(TestApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Unauthenticated_Returns401()
    {
        _factory.ClaimsProvider.ClearClaims();

        var response = await _client.GetAsync("/api/products");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Authenticated_WithScope_Returns200()
    {
        _factory.ClaimsProvider.SetClaims(new[]
        {
            new Claim("sub", "123"),
            new Claim("scope", "api1")
        });

        var response = await _client.GetAsync("/api/products");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
```

## Notes

- Returning `NoResult()` (not `Fail()`) when there are no claims yields a proper `401` challenge.
- Because the provider is a singleton on the factory, reset it (`ClearClaims`) at the start of each test to avoid state leaking across tests, particularly if tests run in parallel.
- You never disable authorization, so `403` scenarios (e.g. authenticated but missing `role=admin`) can also be tested by setting claims that fail a policy.
