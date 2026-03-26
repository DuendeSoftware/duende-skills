# Testing AdminOnly Policy

## Tests

```csharp
public class AdminPolicyTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public AdminPolicyTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureTestServices(services =>
            {
                services.AddAuthentication("Test")
                    .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>("Test", _ => { });
            });
        });
    }

    [Fact]
    public async Task Admin_Gets204()
    {
        TestAuthHandler.TestClaims = new List<Claim>
        {
            new("sub", "user-1"),
            new("role", "admin")
        };

        var client = _factory.CreateClient();
        var response = await client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task Viewer_Gets403()
    {
        TestAuthHandler.TestClaims = new List<Claim>
        {
            new("sub", "user-2"),
            new("role", "viewer")
        };

        var client = _factory.CreateClient();
        var response = await client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task NoAuth_Gets401()
    {
        TestAuthHandler.TestClaims = null;

        var client = _factory.CreateClient();
        var response = await client.DeleteAsync("/api/products/1");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
```
