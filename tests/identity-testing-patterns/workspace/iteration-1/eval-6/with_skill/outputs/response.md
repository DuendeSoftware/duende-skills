# Parsing and Validating Issued Token Claims

After issuing a token via `RequestClientCredentialsTokenAsync`, parse the JWT locally and assert on specific claims.

```csharp
using IdentityModel.Client;
using Microsoft.IdentityModel.JsonWebTokens;
using IdentityModel;
using Xunit;

[Collection("IdentityServer")]
public class TokenClaimsTests : IClassFixture<IdentityServerFactory>
{
    private readonly HttpClient _client;

    public TokenClaimsTests(IdentityServerFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task IssuedToken_ShouldContainExpectedClaims()
    {
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

        // Assert client_id
        Assert.Equal("test.service", jwt.GetClaim(JwtClaimTypes.ClientId).Value);

        // Assert scope
        var scopeValue = jwt.GetClaim(JwtClaimTypes.Scope).Value;
        Assert.Contains("api1", scopeValue.Split(' '));

        // Assert issuer
        Assert.Equal("https://localhost", jwt.Issuer);

        // Assert token is still valid
        Assert.True(jwt.ValidTo > DateTime.UtcNow);
    }
}
```

**Key points:**
- Uses `JsonWebTokenHandler.ReadJsonWebToken()` to parse the access token string locally without making a network call.
- Asserts the `client_id` claim matches `"test.service"`.
- Asserts the `scope` claim contains `"api1"`.
- Asserts the `iss` (issuer) claim matches the expected authority URL.
- No external validation call is made — the token is parsed locally.
