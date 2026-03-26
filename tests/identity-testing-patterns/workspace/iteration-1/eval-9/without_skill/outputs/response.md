# Testing BFF Endpoints

## Testing /bff/user

When testing BFF endpoints, you need to handle cookies for session management.

```csharp
public class BffTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public BffTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
    }

    [Fact]
    public async Task UserEndpoint_NoSession_Returns401()
    {
        var response = await _client.GetAsync("/bff/user");

        // Without a session, should get 401
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task LocalApi_NeedsAntiforgery()
    {
        var response = await _client.GetAsync("/api/data");

        // Missing x-csrf header should be rejected
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
```
