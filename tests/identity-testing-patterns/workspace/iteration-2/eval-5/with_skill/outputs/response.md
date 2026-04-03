# Integration Testing the AdminOnly Policy on DELETE /api/products/{id}

Here's how to test the `AdminOnly` policy using the `TestAuthHandler` pattern, verifying 204 for admin, 403 for viewer, and 401 for unauthenticated.

## 1. TestAuthHandler and Supporting Types

```csharp
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

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

## 2. WebApplicationFactory

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

## 3. Integration Tests

```csharp
using System.Net;
using System.Security.Claims;
using Xunit;

public class AdminOnlyPolicyTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public AdminOnlyPolicyTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task DeleteProduct_AsAdmin_ShouldReturn204()
    {
        _factory.ClaimsProvider.SetClaims(
        [
            new Claim("sub", "user-001"),
            new Claim("role", "admin")
        ]);

        var response = await _client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task DeleteProduct_AsViewer_ShouldReturn403()
    {
        _factory.ClaimsProvider.SetClaims(
        [
            new Claim("sub", "user-002"),
            new Claim("role", "viewer")
        ]);

        var response = await _client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task DeleteProduct_Unauthenticated_ShouldReturn401()
    {
        _factory.ClaimsProvider.ClearClaims();

        var response = await _client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```

Key points:
- Each test sets distinct claims via `ClaimsProvider.SetClaims()` or `ClearClaims()` before making the request.
- Admin role gets `204 NoContent`, viewer role gets `403 Forbidden`, no auth gets `401 Unauthorized`.
- The test class uses `IClassFixture<ApiFactory>` to share the factory across tests.
- Authorization policies remain active — only the authentication source is replaced.
