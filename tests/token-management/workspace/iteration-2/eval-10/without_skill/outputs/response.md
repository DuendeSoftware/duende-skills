# Implementing IClientAssertionService

Client assertions allow you to authenticate to the token endpoint using a signed JWT instead of a shared secret. Here's an implementation.

## `JwtClientAssertionService.cs`

```csharp
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;
using Microsoft.IdentityModel.JsonWebTokens;

public class JwtClientAssertionService : IClientAssertionService
{
    private readonly SigningCredentials _signingCredentials;

    public JwtClientAssertionService(SigningCredentials signingCredentials)
    {
        _signingCredentials = signingCredentials;
    }

    public Task<ClientAssertion?> GetClientAssertionAsync(
        string? clientName = null,
        TokenRequestParameters? parameters = null)
    {
        var now = DateTime.UtcNow;

        var token = new SecurityTokenDescriptor
        {
            Issuer = "my_client_id",
            Audience = "https://identity.example.com/connect/token",
            Expires = now.AddMinutes(5),
            IssuedAt = now,
            SigningCredentials = _signingCredentials,
            Claims = new Dictionary<string, object>
            {
                ["sub"] = "my_client_id",
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
var rsaKey = RSA.Create();
rsaKey.ImportFromPem(builder.Configuration["ClientAssertion:PrivateKeyPem"]);
var signingCredentials = new SigningCredentials(
    new RsaSecurityKey(rsaKey), SecurityAlgorithms.RsaSha256);

builder.Services.AddSingleton<IClientAssertionService>(
    new JwtClientAssertionService(signingCredentials));
```

## Notes

- The JWT audience should be the token endpoint URL where you're sending the assertion.
- The `sub` claim should match your client ID.
- Include a unique `jti` claim to prevent replay attacks.
- Use a short expiration (5 minutes is typical).
- Register the service with DI so the token management library picks it up.
