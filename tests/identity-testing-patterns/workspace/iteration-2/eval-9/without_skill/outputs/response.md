# Testing BFF Endpoints

For testing a BFF (Backend for Frontend) application, you need to handle cookie-based sessions and verify endpoint security.

## Testing the /bff/user Endpoint

The `/bff/user` endpoint should return the current user's claims when logged in, or an error when there's no session.

```csharp
using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

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
    public async Task UserEndpoint_WithoutLogin_ReturnsUnauthorized()
    {
        var response = await _client.GetAsync("/bff/user");

        // Without a session, expect 401 or a redirect to login
        Assert.True(
            response.StatusCode == HttpStatusCode.Unauthorized ||
            response.StatusCode == HttpStatusCode.Redirect);
    }

    [Fact]
    public async Task ApiEndpoint_WithoutCsrfHeader_ReturnsBadRequest()
    {
        // BFF local API endpoints typically require an antiforgery header
        var response = await _client.GetAsync("/api/data");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task ApiEndpoint_WithCsrfHeader_DoesNotReturn400()
    {
        _client.DefaultRequestHeaders.Add("x-csrf", "1");

        var response = await _client.GetAsync("/api/data");

        // May still get 401 (no session), but not 400 (antiforgery failure)
        Assert.NotEqual(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
```

The key thing with BFF testing is that local API endpoints require an `x-csrf` antiforgery header. Without it, BFF returns 400 Bad Request before even checking authentication. The `/bff/user` endpoint returns 401 when there's no active session.
