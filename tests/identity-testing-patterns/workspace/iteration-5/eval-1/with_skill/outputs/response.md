# Integration Testing a Protected Web API with a TestAuthHandler

Your `Program.cs` protects endpoints with JWT Bearer and two policies (`ApiScope`, `AdminOnly`). To test these without a live IdentityServer, replace **authentication** with a `TestAuthHandler` that injects a `ClaimsPrincipal` you control per-test. Authorization keeps running normally — you are only swapping the identity source, so `401`/`403` behavior is still exercised.

## 1. The TestAuthHandler

```csharp
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

public sealed class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string SchemeName = "Test";

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
        if (claims is null)
            // No claims configured => treat as unauthenticated => 401
            return Task.FromResult(AuthenticateResult.NoResult());

        var identity = new ClaimsIdentity(claims, SchemeName);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

Returning `AuthenticateResult.NoResult()` (rather than `Fail`) makes the endpoint's `[Authorize]` produce a proper `401 Unauthorized` challenge when no identity is present.

## 2. The per-test claims provider

```csharp
using System.Security.Claims;

public interface ITestClaimsProvider
{
    IEnumerable<Claim>? GetClaims();
}

public sealed class TestClaimsProvider : ITestClaimsProvider
{
    private IEnumerable<Claim>? _claims;

    public void SetClaims(IEnumerable<Claim> claims) => _claims = claims;
    public void ClearClaims() => _claims = null;
    public IEnumerable<Claim>? GetClaims() => _claims;
}
```

## 3. The WebApplicationFactory registering the test scheme

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

public sealed class ApiFactory : WebApplicationFactory<Program>
{
    // Exposed so each test can set the identity before making a request
    public TestClaimsProvider ClaimsProvider { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddSingleton<ITestClaimsProvider>(ClaimsProvider);

            // Register the test scheme as the default. Authorization policies
            // (ApiScope, AdminOnly) are untouched and still enforced.
            services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                    TestAuthHandler.SchemeName, _ => { });
        });
    }
}
```

> Note: we do **not** touch `AddAuthorization`. The `ApiScope` and `AdminOnly` policies remain active, so a valid-but-under-privileged principal still gets `403`, and a missing principal gets `401`.

## 4. Example tests (401 unauthenticated, 200 authenticated)

```csharp
using System.Net;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc.Testing;

public class ProductsApiTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public ProductsApiTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetProducts_Unauthenticated_ShouldReturn401()
    {
        _factory.ClaimsProvider.ClearClaims(); // no identity injected

        var response = await _client.GetAsync("/api/products");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetProducts_WithApiScope_ShouldReturn200()
    {
        _factory.ClaimsProvider.SetClaims(
        [
            new Claim("sub", "user-001"),
            new Claim("name", "Alice"),
            new Claim("scope", "api1")   // satisfies the ApiScope policy
        ]);

        var response = await _client.GetAsync("/api/products");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
```

## Why this pattern

- **Full control of identity per-test** — set exactly the claims a scenario needs.
- **No token serialization / no live authority** — deterministic and fast.
- **Authorization stays real** — because you only replaced authentication, you can still assert `401` (no principal) and `403` (wrong claims), which you could not do if you disabled authorization wholesale.

### Avoiding cross-test bleed
Because `ClaimsProvider` state is shared through the factory, either create a fresh client per test (as above) and set/clear claims at the start of each test, or reset it in `IAsyncLifetime.InitializeAsync` with `_factory.ClaimsProvider.ClearClaims();` to prevent identity from one parallel test leaking into another.
