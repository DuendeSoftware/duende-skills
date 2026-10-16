# AdminOnly policy tests against DELETE /api/products/{id}

Using the `TestAuthHandler` pattern: the handler injects a `ClaimsPrincipal` you set per test; authorization policies run for real so 403 is testable.

## Handler and claims provider
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

## Tests
```csharp
public class AdminPolicyTests : IClassFixture<ApiFactory>, IAsyncLifetime
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public AdminPolicyTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();      // fresh client per test class instance (xunit creates one per test)
    }

    // Reset so identity never bleeds from one test into the next
    public Task InitializeAsync() { _factory.ClaimsProvider.ClearClaims(); return Task.CompletedTask; }
    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task Delete_WithAdminRole_ShouldReturn204()
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
    public async Task Delete_WithViewerRole_ShouldReturn403()
    {
        _factory.ClaimsProvider.SetClaims(
        [
            new Claim("sub", "user-002"),
            new Claim("role", "viewer")      // ❌ not admin
        ]);

        var response = await _client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Delete_WithoutAuthentication_ShouldReturn401()
    {
        _factory.ClaimsProvider.ClearClaims();    // no claims => NoResult => challenge

        var response = await _client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```

## Why each status
| Case | Handler result | Outcome |
|---|---|---|
| admin | authenticated principal with `role=admin` | policy `RequireClaim("role","admin")` passes → **204** |
| viewer | authenticated, no admin role | policy fails → forbid → **403** |
| none | `AuthenticateResult.NoResult()` | challenge → **401** |

Don't remove or replace authorization with an allow-all handler to "make tests pass" — you'd lose the 403 case. Only the authentication source is swapped. The `ClaimsIdentity` is created with an authentication type (`"Test"`), which is what makes it authenticated.
