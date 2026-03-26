# Client Assertions (private_key_jwt) with Duende.AccessTokenManagement

Client assertions allow you to authenticate to the token endpoint using a signed JWT instead of a shared secret. This is the `private_key_jwt` client authentication method from the OpenID Connect specification.

## Implementation

You need to implement `IClientAssertionService`:

```csharp
public class JwtClientAssertionService : IClientAssertionService
{
    private readonly SigningCredentials _signingCredentials;
    private readonly string _clientId;

    public JwtClientAssertionService(SigningCredentials signingCredentials, string clientId)
    {
        _signingCredentials = signingCredentials;
        _clientId = clientId;
    }

    public Task<ClientAssertion?> GetClientAssertionAsync(
        string? clientName = null,
        TokenRequestParameters? parameters = null)
    {
        var now = DateTime.UtcNow;

        var token = new SecurityTokenDescriptor
        {
            Issuer = _clientId,
            Audience = "https://identity.example.com/connect/token",
            Expires = now.AddMinutes(5),
            IssuedAt = now,
            SigningCredentials = _signingCredentials,
            Claims = new Dictionary<string, object>
            {
                ["sub"] = _clientId,
                ["jti"] = Guid.NewGuid().ToString()
            }
        };

        var handler = new JsonWebTokenHandler();
        var jwt = handler.CreateToken(token);

        return Task.FromResult<ClientAssertion?>(new ClientAssertion
        {
            Type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
            Value = jwt
        });
    }
}
```

## Registration

```csharp
var jwkJson = builder.Configuration["ClientAssertion:JsonWebKey"];
var jwk = new JsonWebKey(jwkJson);
var signingCredentials = new SigningCredentials(jwk, SecurityAlgorithms.RsaSha256);

builder.Services.AddSingleton<IClientAssertionService>(
    new JwtClientAssertionService(signingCredentials, "my-client-id"));
```

## Notes

- The JWT audience should be set to the token endpoint URL
- The assertion type is `urn:ietf:params:oauth:client-assertion-type:jwt-bearer`
- Keep JWT expiration short (5 minutes is recommended)
- Load keys from secure storage, not hardcoded
