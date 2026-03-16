# Parsing JWT Token Claims After Issuance

```csharp
using IdentityModel.Client;
using System.IdentityModel.Tokens.Jwt;
using Xunit;

public class TokenClaimTests : IClassFixture<IdentityServerTestFactory>
{
    private readonly HttpClient _client;

    public TokenClaimTests(IdentityServerTestFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Token_ContainsExpectedClaims()
    {
        var tokenResponse = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = "https://localhost/connect/token",
                ClientId = "test-client",
                ClientSecret = "secret",
                Scope = "api1"
            });

        Assert.False(tokenResponse.IsError);

        var handler = new JwtSecurityTokenHandler();
        var token = handler.ReadJwtToken(tokenResponse.AccessToken);

        // Check client_id
        var clientId = token.Claims.FirstOrDefault(c => c.Type == "client_id")?.Value;
        Assert.Equal("test-client", clientId);

        // Check scope
        var scope = token.Claims.FirstOrDefault(c => c.Type == "scope")?.Value;
        Assert.Equal("api1", scope);

        // Check issuer
        Assert.NotNull(token.Issuer);
    }
}
```

This parses the JWT token locally and checks the claims without making additional network calls.
