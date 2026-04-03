# Validating JWT Claims from an In-Process IdentityServer Token

Here's how to issue a client credentials token from an in-process IdentityServer, then parse the JWT and validate its claims locally.

## 1. Issue the Token

```csharp
using IdentityModel.Client;

var tokenResponse = await _client.RequestClientCredentialsTokenAsync(
    new ClientCredentialsTokenRequest
    {
        Address = new Uri(_client.BaseAddress!, "connect/token").ToString(),
        ClientId = "test.service",
        ClientSecret = "test-secret",
        Scope = "api1"
    });

Assert.False(tokenResponse.IsError, tokenResponse.Error);
```

## 2. Parse and Assert Claims

```csharp
using Microsoft.IdentityModel.JsonWebTokens;
using IdentityModel;
using Xunit;

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

    // Assert scope contains the expected value
    var scopeValue = jwt.GetClaim(JwtClaimTypes.Scope).Value;
    Assert.Contains("api1", scopeValue.Split(' '));

    // Assert issuer
    Assert.Equal("https://localhost", jwt.Issuer);

    // Assert token hasn't expired
    Assert.True(jwt.ValidTo > DateTime.UtcNow);
}
```

Key points:
- `JsonWebTokenHandler.ReadJsonWebToken` is used to parse the access token string — this is a local parse, **no network call** to validate the token.
- The `client_id` claim is asserted to match `"test.service"` (the test client's ID).
- The `scope` claim is asserted to contain `"api1"`.
- The `iss` (issuer) claim is asserted to match the expected authority URL.
- The token's expiry is verified to be in the future.
