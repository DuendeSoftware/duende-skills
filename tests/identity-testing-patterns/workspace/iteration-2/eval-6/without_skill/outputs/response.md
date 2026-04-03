# Parsing JWT Claims After Token Issuance

After obtaining a token from your IdentityServer, you can parse the JWT to inspect its claims.

## Example

```csharp
using System.IdentityModel.Tokens.Jwt;
using IdentityModel.Client;
using Xunit;

[Fact]
public async Task CanParseTokenClaims()
{
    var tokenResponse = await _client.RequestClientCredentialsTokenAsync(
        new ClientCredentialsTokenRequest
        {
            Address = "https://localhost/connect/token",
            ClientId = "test.service",
            ClientSecret = "test-secret",
            Scope = "api1"
        });

    Assert.False(tokenResponse.IsError);

    // Parse the JWT
    var handler = new JwtSecurityTokenHandler();
    var jwt = handler.ReadJwtToken(tokenResponse.AccessToken);

    // Check client_id
    var clientId = jwt.Claims.FirstOrDefault(c => c.Type == "client_id")?.Value;
    Assert.Equal("test.service", clientId);

    // Check scope
    var scope = jwt.Claims.FirstOrDefault(c => c.Type == "scope")?.Value;
    Assert.Equal("api1", scope);

    // Check issuer
    Assert.Equal("https://localhost", jwt.Issuer);
}
```

The `JwtSecurityTokenHandler.ReadJwtToken` parses the JWT without validating the signature, which is fine for inspecting claims in tests. You can check `client_id`, `scope`, `iss`, and any other claims the token should contain. This is all done locally with no network calls.
