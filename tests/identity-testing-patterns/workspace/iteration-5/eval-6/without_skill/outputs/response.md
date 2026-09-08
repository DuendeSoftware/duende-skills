# Reading and Asserting JWT Claims After Token Issuance

Once you have the access token string from `RequestClientCredentialsTokenAsync`, you can decode it locally and assert on its claims without calling any endpoint. Use `JsonWebTokenHandler.ReadJsonWebToken` (or `JwtSecurityTokenHandler.ReadJwtToken`) to parse it.

```csharp
using IdentityModel.Client;
using Microsoft.IdentityModel.JsonWebTokens;

public class TokenClaimsTests : IClassFixture<IdentityServerFactory>
{
    private readonly HttpClient _client;

    public TokenClaimsTests(IdentityServerFactory factory)
        => _client = factory.CreateClient();

    [Fact]
    public async Task Issued_token_has_expected_claims()
    {
        // Issue the token
        var response = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = "connect/token",
                ClientId = "test-client",
                ClientSecret = "secret",
                Scope = "api1"
            });

        Assert.False(response.IsError, response.Error);

        // Parse the JWT locally (no network round-trip)
        var handler = new JsonWebTokenHandler();
        var jwt = handler.ReadJsonWebToken(response.AccessToken);

        // client_id
        Assert.Equal("test-client", jwt.GetClaim("client_id").Value);

        // scope (space-delimited in the token)
        var scope = jwt.GetClaim("scope").Value;
        Assert.Contains("api1", scope.Split(' '));

        // issuer
        Assert.Equal("https://localhost", jwt.Issuer);
    }
}
```

## Notes
- `ReadJsonWebToken` decodes the token structure and lets you read claims via `GetClaim(...)`; it does not perform signature validation, which is fine when you only want to inspect the claims.
- The `scope` claim is a single space-separated string in an access token, so split it before checking membership.
- `jwt.Issuer` exposes the `iss` claim; assert it equals your IdentityServer's authority URL.
- This is a purely local operation — no introspection or userinfo request is made.

> Alternatively, `new JwtSecurityTokenHandler().ReadJwtToken(response.AccessToken)` gives a `JwtSecurityToken` whose `.Claims`, `.Issuer`, etc. you can assert on the same way.
