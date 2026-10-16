# Parsing and asserting claims of an issued access token

```csharp
using System.IdentityModel.Tokens.Jwt;
using Duende.IdentityModel.Client;

public class TokenClaimsTests : IClassFixture<IdentityServerFactory>
{
    private readonly IdentityServerFactory _factory;
    public TokenClaimsTests(IdentityServerFactory f) => _factory = f;

    [Fact]
    public async Task Access_token_contains_expected_claims()
    {
        var client = _factory.CreateClient();
        var disco = await client.GetDiscoveryDocumentAsync();
        Assert.False(disco.IsError, disco.Error);

        var response = await client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
        {
            Address = disco.TokenEndpoint,
            ClientId = "test-client",
            ClientSecret = "secret",
            Scope = "api1"
        });
        Assert.False(response.IsError, response.Error);

        // Parse without validating (we trust our own in-process server)
        var jwt = new JwtSecurityTokenHandler().ReadJwtToken(response.AccessToken);

        Assert.Equal(disco.Issuer, jwt.Issuer);
        Assert.Equal("test-client", jwt.Claims.First(c => c.Type == "client_id").Value);

        var scopes = jwt.Claims.Where(c => c.Type == "scope").Select(c => c.Value).ToList();
        Assert.Contains("api1", scopes);

        Assert.True(jwt.ValidTo > DateTime.UtcNow);
    }
}
```

Notes:
- `JwtSecurityTokenHandler.ReadJwtToken` only decodes; it doesn't validate the signature. `ReadJwtToken` doesn't remap claim types, so `client_id` and `scope` keep their names. (`JwtSecurityTokenHandler.DefaultInboundClaimTypeMap` only matters when validating into a ClaimsPrincipal.)
- The `scope` claim is a single string if one scope, and multiple `scope` claims if several – hence `Where(...)`.
- The `aud` claim is only present if an ApiResource is defined or `EmitStaticAudienceClaim` is on (static audience `issuer/resources`).
- Use `Assert.Equal(expectedIssuer, jwt.Issuer)` with a literal if you want to pin it; with TestServer it is typically `http://localhost`.
- To also validate the signature, fetch `disco.KeySet` and use `JwtSecurityTokenHandler.ValidateToken` with those keys as `IssuerSigningKeys`.
- Alternative: use `Microsoft.IdentityModel.JsonWebTokens.JsonWebTokenHandler` with `new JsonWebToken(token)`.
