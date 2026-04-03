# Testing Authorization Policy on DELETE Endpoint

Here's how to test that the `AdminOnly` policy works correctly using a test authentication handler.

## Test Setup

```csharp
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

public static class TestIdentity
{
    public static ClaimsPrincipal? CurrentUser { get; set; }
}

public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : base(options, logger, encoder) { }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (TestIdentity.CurrentUser is null)
            return Task.FromResult(AuthenticateResult.NoResult());

        return Task.FromResult(AuthenticateResult.Success(
            new AuthenticationTicket(TestIdentity.CurrentUser, "TestScheme")));
    }
}

public class TestApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddAuthentication("TestScheme")
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                    "TestScheme", _ => { });
        });
    }
}
```

## Tests

```csharp
using System.Net;
using System.Security.Claims;
using Xunit;

public class AdminPolicyTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;

    public AdminPolicyTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Admin_CanDeleteProduct()
    {
        TestIdentity.CurrentUser = new ClaimsPrincipal(
            new ClaimsIdentity(new[]
            {
                new Claim("sub", "admin-user"),
                new Claim("role", "admin")
            }, "TestScheme"));

        var response = await _client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task Viewer_GetsForbidden()
    {
        TestIdentity.CurrentUser = new ClaimsPrincipal(
            new ClaimsIdentity(new[]
            {
                new Claim("sub", "viewer-user"),
                new Claim("role", "viewer")
            }, "TestScheme"));

        var response = await _client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Anonymous_GetsUnauthorized()
    {
        TestIdentity.CurrentUser = null;

        var response = await _client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```

Each test sets the `TestIdentity.CurrentUser` to different claims (or null for unauthenticated) before making the request. The class uses `IClassFixture<TestApiFactory>` to share the factory.
