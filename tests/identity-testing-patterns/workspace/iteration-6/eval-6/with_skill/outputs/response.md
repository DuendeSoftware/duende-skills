# Parsing an issued token and asserting its claims

After requesting a token from the in-process IdentityServer, read the JWT with `JsonWebTokenHandler` (no extra network call) and assert on `client_id`, `scope`, and the issuer.

```csharp
using Duende.IdentityModel;
using Duende.IdentityModel.Client;
using Microsoft.IdentityModel.JsonWebTokens;

public class IssuedTokenTests : IClassFixture<IdentityServerFactory>
{
    private readonly HttpClient _client;

    public IssuedTokenTests(IdentityServerFactory factory) => _client = factory.CreateClient();

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

        // Parse without validating the signature (we trust our own in-process server)
        var handler = new JsonWebTokenHandler();
        var jwt = handler.ReadJsonWebToken(tokenResponse.AccessToken);

        Assert.Equal("test.service", jwt.GetClaim(JwtClaimTypes.ClientId).Value);
        Assert.Contains("api1", jwt.GetClaim(JwtClaimTypes.Scope).Value.Split(' '));
        Assert.Equal("https://localhost", jwt.Issuer);
        Assert.True(jwt.ValidTo > DateTime.UtcNow);
    }
}
```

Notes:
- `JsonWebToken` doesn't remap claim types, so `client_id` and `scope` keep their JWT names.
- `scope` for a single scope is a string; a multi-scope token may carry it as a JSON array, in which case use `jwt.Claims.Where(c => c.Type == "scope")` instead of `Split`. The `Claims` collection handles both.
- Issuer: with `WebApplicationFactory` the server base address is `https://localhost`, so the issuer is that unless you set `IssuerUri`. Prefer reading the expected value from the discovery document (`disco.Issuer`) if you don't want to hard-code it.
- To also verify the signature, take the JWKS from the discovery document (`disco.KeySet`) and call `handler.ValidateTokenAsync` with `IssuerSigningKeys`, matching the static dev signing key. The factory should use `KeyManagement.Enabled = false` + `AddDeveloperSigningCredential(persistKey: false)` for predictability.
- Don't hard-code `http://localhost:5001`; it causes port conflicts in CI. Use the factory's `BaseAddress`.
