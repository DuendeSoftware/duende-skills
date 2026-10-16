# TestAuthHandler for the protected API

Replace JWT Bearer with a `TestAuthHandler` that injects a `ClaimsPrincipal` you control per test. Authorization still runs normally (don't disable it wholesale), so your `ApiScope` / `AdminOnly` policies are really exercised. Your `Program.cs` already has `public partial class Program { }`, so `WebApplicationFactory<Program>` works.

Packages: `Microsoft.AspNetCore.Mvc.Testing`, `xunit`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`.

## Handler + claims provider
```csharp
public sealed class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string SchemeName = "Test";
    private readonly ITestClaimsProvider _claimsProvider;

    public TestAuthHandler(IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger, UrlEncoder encoder, ITestClaimsProvider claimsProvider)
        : base(options, logger, encoder) => _claimsProvider = claimsProvider;

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = _claimsProvider.GetClaims();
        if (claims is null)
            return Task.FromResult(AuthenticateResult.NoResult());   // => 401 via challenge

        var identity = new ClaimsIdentity(claims, SchemeName);
        var ticket = new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}

public interface ITestClaimsProvider { IEnumerable<Claim>? GetClaims(); }

public sealed class TestClaimsProvider : ITestClaimsProvider
{
    private IEnumerable<Claim>? _claims;
    public void SetClaims(IEnumerable<Claim> claims) => _claims = claims;
    public void ClearClaims() => _claims = null;
    public IEnumerable<Claim>? GetClaims() => _claims;
}
```

No claims → `NoResult` → unauthenticated → the policy challenge returns **401**.

## Factory
```csharp
public sealed class ApiFactory : WebApplicationFactory<Program>
{
    // Exposed so each test controls the identity
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
`DefaultScheme`-based registration (`AddAuthentication(TestAuthHandler.SchemeName)`) makes the test scheme the default, so the `[Authorize(Policy=...)]` endpoints use it, and the real JWT handler never contacts `https://localhost:5001`.

## Tests
```csharp
public class ProductsApiTests : IClassFixture<ApiFactory>, IAsyncLifetime
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public ProductsApiTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    // Reset identity before each test so nothing bleeds between tests
    public Task InitializeAsync() { _factory.ClaimsProvider.ClearClaims(); return Task.CompletedTask; }
    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task GetProducts_Unauthenticated_ShouldReturn401()
    {
        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetProducts_WithApi1Scope_ShouldReturn200()
    {
        _factory.ClaimsProvider.SetClaims(
        [
            new Claim("sub", "user-001"),
            new Claim("scope", "api1")
        ]);

        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetProducts_AuthenticatedWithoutScope_ShouldReturn403()
    {
        _factory.ClaimsProvider.SetClaims([new Claim("sub", "user-002")]);

        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
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
}
```

## Pitfalls
- **Shared state:** `ClaimsProvider` is a singleton per factory. Because xunit runs tests *within a class* sequentially but classes in parallel, use one fixture per class (as above) and reset/set claims at the start of each test. Don't share a static `HttpClient` across classes.
- Never swap authorization for an allow-all handler — you'd lose the ability to test 403.
- 401 = no authenticated principal; 403 = authenticated but policy failed.
