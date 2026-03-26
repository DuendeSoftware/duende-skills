# Reading Token Claims After Issuance

```csharp
[Fact]
public async Task Token_HasExpectedClaims()
{
    var response = await _client.RequestClientCredentialsTokenAsync(
        new ClientCredentialsTokenRequest
        {
            Address = "https://localhost/connect/token",
            ClientId = "test.service",
            ClientSecret = "test-secret",
            Scope = "api1"
        });

    Assert.False(response.IsError);

    var handler = new JwtSecurityTokenHandler();
    var token = handler.ReadJwtToken(response.AccessToken);

    // Check claims
    var clientId = token.Claims.First(c => c.Type == "client_id").Value;
    Assert.Equal("test.service", clientId);

    var scope = token.Claims.First(c => c.Type == "scope").Value;
    Assert.Equal("api1", scope);

    Assert.Equal("https://localhost", token.Issuer);
}
```

This parses the JWT locally without calling any validation endpoint.
