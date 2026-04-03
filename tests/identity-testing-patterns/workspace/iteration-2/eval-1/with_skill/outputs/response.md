# TestAuthHandler for Integration Testing Protected APIs

Here's how to create a `TestAuthHandler` that lets you control the `ClaimsPrincipal` per-test and verify that unauthenticated requests return 401, while keeping authorization policies active.

## 1. ITestClaimsProvider Interface

```csharp
// Swap this per-test to change the authenticated user
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

## 2. TestAuthHandler Implementation

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
            return Task.FromResult(AuthenticateResult.NoResult());

        var identity = new ClaimsIdentity(claims, SchemeName);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

## 3. WebApplicationFactory Registration

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

public sealed class ApiFactory : WebApplicationFactory<Program>
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

## 4. Example Tests

```csharp
using System.Net;
using System.Security.Claims;
using Xunit;

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
        // Clear claims = no authenticated user
        _factory.ClaimsProvider.ClearClaims();

        var response = await _client.GetAsync("/api/products");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetProducts_Authenticated_ShouldReturn200()
    {
        _factory.ClaimsProvider.SetClaims(
        [
            new Claim("sub", "user-001"),
            new Claim("scope", "api1")
        ]);

        var response = await _client.GetAsync("/api/products");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
```

Key points:
- The `TestAuthHandler` extends `AuthenticationHandler<AuthenticationSchemeOptions>` and returns `AuthenticateResult.NoResult()` when claims are null, causing the pipeline to return 401.
- Authorization policies (`AdminOnly`, `ApiScope`) remain fully active — we only replace the authentication source, not the authorization layer.
- Each test controls the identity via `ClaimsProvider.SetClaims()` or `ClaimsProvider.ClearClaims()`.
