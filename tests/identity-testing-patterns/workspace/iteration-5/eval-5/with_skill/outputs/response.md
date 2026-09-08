# Integration-Testing the AdminOnly Policy on DELETE /api/products/{id}

The endpoint `DELETE /api/products/{id:int}` is guarded by `[Authorize(Policy = "AdminOnly")]`, and `AdminOnly` requires `role=admin`. Using the `TestAuthHandler` pattern you can drive three scenarios by swapping the injected claims, while the real authorization policy stays active:

- admin role → `204 No Content`
- viewer role → `403 Forbidden`
- no auth → `401 Unauthorized`

## TestAuthHandler + claims provider

```csharp
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

public interface ITestClaimsProvider { IEnumerable<Claim>? GetClaims(); }

public sealed class TestClaimsProvider : ITestClaimsProvider
{
    private IEnumerable<Claim>? _claims;
    public void SetClaims(IEnumerable<Claim> claims) => _claims = claims;
    public void ClearClaims() => _claims = null;
    public IEnumerable<Claim>? GetClaims() => _claims;
}

public sealed class TestAuthHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    ITestClaimsProvider claimsProvider)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "Test";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = claimsProvider.GetClaims();
        if (claims is null)
            return Task.FromResult(AuthenticateResult.NoResult()); // => 401

        var identity = new ClaimsIdentity(claims, SchemeName);
        var ticket = new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

## Factory (authorization left intact)

```csharp
using Microsoft.AspNetCore.Authentication;
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
            services.AddSingleton<ITestClaimsProvider>(ClaimsProvider);

            services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                    TestAuthHandler.SchemeName, _ => { });
            // NOTE: AdminOnly policy from Program.cs remains active.
        });
    }
}
```

## The three tests

```csharp
using System.Net;
using System.Security.Claims;

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
    public async Task Delete_AsAdmin_Returns204()
    {
        _factory.ClaimsProvider.SetClaims(
        [
            new Claim("sub", "admin-1"),
            new Claim("role", "admin")   // satisfies AdminOnly
        ]);

        var response = await _client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode); // 204
    }

    [Fact]
    public async Task Delete_AsViewer_Returns403()
    {
        _factory.ClaimsProvider.SetClaims(
        [
            new Claim("sub", "viewer-1"),
            new Claim("role", "viewer")  // authenticated but not admin
        ]);

        var response = await _client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode); // 403
    }

    [Fact]
    public async Task Delete_Unauthenticated_Returns401()
    {
        _factory.ClaimsProvider.ClearClaims(); // no identity

        var response = await _client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode); // 401
    }
}
```

## Why the status codes come out right
- **204** — admin claim satisfies `AdminOnly`, the endpoint runs and returns `Results.NoContent()`.
- **403** — the viewer *is authenticated* (a principal exists) but fails the `role=admin` requirement, so authorization returns Forbidden rather than a challenge.
- **401** — with no claims, `HandleAuthenticateAsync` returns `NoResult()`, so `[Authorize]` challenges → Unauthorized.

`IClassFixture<ApiFactory>` shares one factory across the test class. Each test sets its own distinct claims (or clears them) before the request, so scenarios stay isolated; reset the provider in `IAsyncLifetime` if you run tests in parallel.
