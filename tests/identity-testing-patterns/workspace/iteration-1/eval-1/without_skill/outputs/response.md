# Testing Protected APIs with a Custom Auth Handler

## Create a Test Authentication Handler

You can create a custom authentication handler that lets you inject claims for testing:

```csharp
public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public static IList<Claim>? TestClaims { get; set; }

    public TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : base(options, logger, encoder)
    {
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (TestClaims is null || TestClaims.Count == 0)
            return Task.FromResult(AuthenticateResult.Fail("No claims configured"));

        var identity = new ClaimsIdentity(TestClaims, "Test");
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, "Test");
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

## WebApplicationFactory Setup

```csharp
public class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddAuthentication("Test")
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>("Test", _ => { });
        });
    }
}
```

## Tests

```csharp
public class ApiTests : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client;

    public ApiTests(ApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetProducts_WithAuth_Returns200()
    {
        TestAuthHandler.TestClaims = new List<Claim>
        {
            new Claim("sub", "user-1"),
            new Claim("scope", "api1")
        };

        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetProducts_NoAuth_Returns401()
    {
        TestAuthHandler.TestClaims = null;

        var response = await _client.GetAsync("/api/products");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```
