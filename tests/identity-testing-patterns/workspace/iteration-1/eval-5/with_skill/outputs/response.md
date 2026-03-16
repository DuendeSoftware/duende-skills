# Integration Testing AdminOnly Policy with TestAuthHandler

Using the TestAuthHandler pattern from the skill, here are integration tests for the DELETE /api/products/{id} endpoint.

## ApiFactory (shared)

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

public class DeleteProductPolicyTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public DeleteProductPolicyTests(ApiFactory factory)
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

Each test sets distinct claims via the `TestClaimsProvider` before making the request. The factory is shared using `IClassFixture<ApiFactory>`.
