# Testing Authorization Policy on DELETE Endpoint

## WebApplicationFactory

```csharp
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.Authentication;

public class TestFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddAuthentication("Test")
                .AddScheme<AuthenticationSchemeOptions, FakeAuthHandler>("Test", o => { });
        });
    }
}
```

## Tests

```csharp
using System.Net;
using System.Security.Claims;
using Xunit;

public class DeleteProductTests
{
    [Fact]
    public async Task Admin_CanDeleteProduct()
    {
        var factory = new TestFactory();
        FakeAuthHandler.Claims = new List<Claim>
        {
            new Claim("sub", "user-1"),
            new Claim("role", "admin")
        };
        var client = factory.CreateClient();

        var response = await client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task Viewer_GetsForbidden()
    {
        var factory = new TestFactory();
        FakeAuthHandler.Claims = new List<Claim>
        {
            new Claim("sub", "user-2"),
            new Claim("role", "viewer")
        };
        var client = factory.CreateClient();

        var response = await client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task NoAuth_GetsUnauthorized()
    {
        var factory = new TestFactory();
        FakeAuthHandler.Claims = null;
        var client = factory.CreateClient();

        var response = await client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```

This uses a static claims pattern on the FakeAuthHandler to control what claims are available for each test.
