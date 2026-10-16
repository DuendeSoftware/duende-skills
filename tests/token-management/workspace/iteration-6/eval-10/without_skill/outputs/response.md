# Client assertions with IClientAssertionService

The CVE-class issue: the JWT `aud` claim should be the **issuer** identifier of the authorization server, not the token endpoint URL (the ambiguity let an attacker-controlled endpoint receive an assertion valid elsewhere). Use `https://sts.example.com` (the issuer), not `https://sts.example.com/connect/token`, where the server requires it; check the discovery document's `issuer`.

```csharp
public class ClientAssertionService(IOptions<AssertionOptions> options) : IClientAssertionService
{
    public Task<ClientAssertion?> GetClientAssertionAsync(
        ClientCredentialsClientName? clientName = null,
        TokenRequestParameters? parameters = null,
        CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        var handler = new JsonWebTokenHandler();
        var jwt = handler.CreateToken(new SecurityTokenDescriptor
        {
            Issuer = "webapp",                       // client_id
            Audience = "https://sts.example.com",    // issuer of the STS
            Subject = new ClaimsIdentity(new[]
            {
                new Claim("sub", "webapp"),
                new Claim("jti", Guid.NewGuid().ToString())
            }),
            IssuedAt = now,
            Expires = now.AddMinutes(1),
            SigningCredentials = new SigningCredentials(options.Value.Key, SecurityAlgorithms.RsaSsaPssSha256)
        });

        return Task.FromResult<ClientAssertion?>(new ClientAssertion
        {
            Type = OidcConstants.ClientAssertionTypes.JwtBearer,
            Value = jwt
        });
    }
}

builder.Services.AddTransient<IClientAssertionService, ClientAssertionService>();
```

Keep expirations short, give each assertion a unique `jti`, never reuse them, and protect the private key (certificate/Key Vault).
