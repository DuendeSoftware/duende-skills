# Validating Issued Token Claims

After issuing a client credentials token from the in-process IdentityServer, parse the JWT locally and assert on its claims.

```csharp
using IdentityModel.Client;
using Microsoft.IdentityModel.JsonWebTokens;
using Xunit;

public class TokenClaimTests : IClassFixture<IdentityServerFactory>
{
    private readonly HttpClient _client;

    public TokenClaimTests(IdentityServerFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task IssuedToken_ShouldContainExpectedClaims()
    {
        // Issue a token
        var tokenResponse = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = new Uri(_client.BaseAddress!, "connect/token").ToString(),
                ClientId = "test.service",
                ClientSecret = "test-secret",
                Scope = "api1"
            });

        Assert.False(tokenResponse.IsError, tokenResponse.Error);

        // Parse the JWT locally — no network call needed
        var handler = new JsonWebTokenHandler();
        var jwt = handler.ReadJsonWebToken(tokenResponse.AccessToken);

        // Assert on claims
        Assert.Equal("test.service", jwt.GetClaim("client_id").Value);
        Assert.Contains("api1", jwt.GetClaim("scope").Value.Split(' '));
        Assert.Equal("https://localhost", jwt.Issuer);
        Assert.True(jwt.ValidTo > DateTime.UtcNow);
    }

    [Fact]
    public async Task IssuedToken_ShouldHaveCorrectTokenType()
    {
        var tokenResponse = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = new Uri(_client.BaseAddress!, "connect/token").ToString(),
                ClientId = "test.service",
                ClientSecret = "test-secret",
                Scope = "api1"
            });

        Assert.False(tokenResponse.IsError);

        var handler = new JsonWebTokenHandler();
        var jwt = handler.ReadJsonWebToken(tokenResponse.AccessToken);

        // Duende IdentityServer issues at+jwt tokens per RFC 9068
        Assert.Equal("at+jwt", jwt.Typ);
    }
}
```

## Key Points

- **`JsonWebTokenHandler.ReadJsonWebToken()`** parses the JWT without validation — it reads the header and payload directly. This is appropriate for test assertions where we trust the issuer (it's our in-process server).
- **No network call**: We don't call the introspection endpoint or the JWKS endpoint. The token string is parsed directly.
- **`jwt.GetClaim("client_id").Value`**: Returns the value of the `client_id` claim in the payload.
- **`jwt.Issuer`**: The `iss` claim — should match the in-process server's base address.
