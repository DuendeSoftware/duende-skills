# TestAuthHandler for Protected API Integration Tests

## 1. ITestClaimsProvider Interface

```csharp
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

## 2. TestAuthHandler

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

## 3. WebApplicationFactory

```csharp
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

public sealed class ApiFactory : WebApplicationFactory<Program>
{
    public TestClaimsProvider ClaimsProvider { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            // Register the test claims provider as a singleton
            services.AddSingleton<ITestClaimsProvider>(ClaimsProvider);

            // Replace the authentication scheme with our test handler
            services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                    TestAuthHandler.SchemeName, _ => { });
        });
    }
}
```

## 4. Tests

```csharp
using System.Net;
using System.Security.Claims;
using Xunit;

public class ProtectedApiTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public ProtectedApiTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetProducts_Authenticated_ShouldReturn200()
    {
        _factory.ClaimsProvider.SetClaims(new[]
        {
            new Claim("sub", "user-001"),
            new Claim("scope", "api1"),
            new Claim("role", "viewer")
        });

        var response = await _client.GetAsync("/api/products");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetProducts_Unauthenticated_ShouldReturn401()
    {
        // Clear claims = no authenticated identity = AuthenticateResult.NoResult()
        _factory.ClaimsProvider.ClearClaims();

        var response = await _client.GetAsync("/api/products");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```

## Key Points

- **TestAuthHandler returns `AuthenticateResult.NoResult()`** when claims are null — this means no authentication ticket is created, and the authorization middleware returns 401 for `[Authorize]` endpoints.
- **Authorization policies remain active** — we only replace the authentication source, not the authorization logic. Policies like `AdminOnly` and `ApiScope` still enforce their claim requirements.
- **ClearClaims() simulates unauthenticated requests** — no need to remove the auth handler or modify middleware.
