# Testing Protected APIs with a Custom Authentication Handler

To test your protected API without a real identity provider, you can create a custom authentication handler that lets you control the user identity per test.

## Custom Auth Handler

```csharp
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

public class FakeAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public static ClaimsPrincipal? TestUser { get; set; }

    public FakeAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : base(options, logger, encoder) { }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (TestUser is null)
            return Task.FromResult(AuthenticateResult.NoResult());

        var ticket = new AuthenticationTicket(TestUser, "FakeScheme");
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

## WebApplicationFactory Setup

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

public class TestApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddAuthentication("FakeScheme")
                .AddScheme<AuthenticationSchemeOptions, FakeAuthHandler>(
                    "FakeScheme", _ => { });
        });
    }
}
```

## Test Examples

```csharp
using System.Net;
using System.Security.Claims;
using Xunit;

public class ApiTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;

    public ApiTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Unauthenticated_Returns401()
    {
        FakeAuthHandler.TestUser = null;

        var response = await _client.GetAsync("/api/products");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Authenticated_Returns200()
    {
        FakeAuthHandler.TestUser = new ClaimsPrincipal(
            new ClaimsIdentity(new[]
            {
                new Claim("sub", "user-001"),
                new Claim("scope", "api1")
            }, "FakeScheme"));

        var response = await _client.GetAsync("/api/products");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
```

This approach replaces JWT Bearer authentication with a fake scheme. You control the user identity by setting the static `TestUser` property before each request. When `TestUser` is null, the handler returns `NoResult()`, which makes the pipeline return 401. Authorization policies still run normally.
