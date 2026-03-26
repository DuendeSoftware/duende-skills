# Integration Testing the AdminOnly Policy

Using the `TestAuthHandler` pattern to test the DELETE `/api/products/{id}` endpoint with different authorization scenarios.

## Factory Setup

```csharp
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

## Tests

```csharp
using System.Net;
using System.Security.Claims;
using Xunit;

public class AdminPolicyTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public AdminPolicyTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task DeleteProduct_AsAdmin_ShouldReturn204()
    {
        _factory.ClaimsProvider.SetClaims(new[]
        {
            new Claim("sub", "admin-user-001"),
            new Claim("role", "admin")
        });

        var response = await _client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task DeleteProduct_AsViewer_ShouldReturn403()
    {
        _factory.ClaimsProvider.SetClaims(new[]
        {
            new Claim("sub", "viewer-user-002"),
            new Claim("role", "viewer")
        });

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

## How It Works

1. **Admin role (204)**: The `AdminOnly` policy requires `role = admin`. The TestAuthHandler injects a principal with that claim, so the policy passes and the endpoint returns `NoContent`.

2. **Viewer role (403)**: The principal is authenticated (has claims) but lacks the `admin` role. The authorization middleware returns `Forbidden` because the policy requirement is not met.

3. **Unauthenticated (401)**: `ClearClaims()` causes `TestAuthHandler.HandleAuthenticateAsync()` to return `AuthenticateResult.NoResult()`. With no authenticated identity, the middleware returns `Unauthorized`.

The `IClassFixture<ApiFactory>` ensures the factory (and its embedded test server) is shared across all tests in the class, avoiding the overhead of creating a new server per test.
