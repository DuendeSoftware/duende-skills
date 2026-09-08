# Parsing and Asserting on Issued Token Claims (No Network Call)

After issuing a client-credentials token from your in-process IdentityServer, you can validate its contents by **parsing the JWT locally** with `JsonWebTokenHandler.ReadJsonWebToken` and asserting on individual claims (`client_id`, `scope`, `iss`). No second network round-trip is needed — you already have the token string.

```csharp
using Duende.IdentityModel;              // JwtClaimTypes
using Duende.IdentityModel.Client;       // RequestClientCredentialsTokenAsync
using Microsoft.IdentityModel.JsonWebTokens;
using System.Net.Http;

public class IssuedTokenClaimsTests : IClassFixture<IdentityServerFactory>
{
    private readonly HttpClient _client;

    public IssuedTokenClaimsTests(IdentityServerFactory factory)
        => _client = factory.CreateClient();

    [Fact]
    public async Task IssuedToken_ContainsExpectedClaims()
    {
        // 1) Issue a token from the in-process /connect/token endpoint
        var tokenResponse = await _client.RequestClientCredentialsTokenAsync(
            new ClientCredentialsTokenRequest
            {
                Address = new Uri(_client.BaseAddress!, "connect/token").ToString(),
                ClientId = "test.service",
                ClientSecret = "test-secret",
                Scope = "api1"
            });

        Assert.False(tokenResponse.IsError, tokenResponse.Error);

        // 2) Parse the JWT locally — no network validation call
        var handler = new JsonWebTokenHandler();
        var jwt = handler.ReadJsonWebToken(tokenResponse.AccessToken);

        // 3) Assert on specific claims
        // client_id matches the requesting client
        Assert.Equal("test.service", jwt.GetClaim(JwtClaimTypes.ClientId).Value);

        // scope contains the requested scope (scope is a space-delimited string)
        var scopes = jwt.GetClaim(JwtClaimTypes.Scope).Value.Split(' ');
        Assert.Contains("api1", scopes);

        // iss matches the authority (the in-process server's base address host)
        Assert.Equal(_client.BaseAddress!.GetLeftPart(UriPartial.Authority), jwt.Issuer);
    }
}
```

## Key points

- **`ReadJsonWebToken` parses without validating the signature.** That's exactly what you want here — the test verifies *the contents IdentityServer put in the token*, not the cryptographic trust chain (which the API would do at runtime). Because the dev signing key isn't externally resolvable, parsing (rather than full validation) keeps the test self-contained.
- **No network call to a userinfo/introspection endpoint.** Everything is read from the token string you already hold, so the test is fast and deterministic.
- `jwt.Issuer` is a convenience property exposing the `iss` claim; `jwt.GetClaim(...)` returns individual claims. `scope` is emitted as a single space-separated string in JWTs, so split before asserting membership.

> If you instead want to *fully validate* (signature + audience + lifetime), configure `TokenValidationParameters` with the same dev signing key and call `handler.ValidateTokenAsync(...)`. For claim-content assertions, local parsing is sufficient and preferred.
