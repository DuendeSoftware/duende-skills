# Client Assertions with JWT

Client assertions let you authenticate your client using signed JWTs instead of shared secrets. This is more secure for production scenarios.

## Implementation

```csharp
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.IdentityModel.Tokens;

public class JwtClientAssertionService : IClientAssertionService
{
    private readonly SigningCredentials _signingCredentials;
    private readonly string _clientId;
    private readonly string _tokenEndpoint;

    public JwtClientAssertionService(
        SigningCredentials signingCredentials,
        string clientId,
        string tokenEndpoint)
    {
        _signingCredentials = signingCredentials;
        _clientId = clientId;
        _tokenEndpoint = tokenEndpoint;
    }

    public Task<ClientAssertion?> GetClientAssertionAsync(
        string? clientName = null,
        TokenRequestParameters? parameters = null)
    {
        var now = DateTime.UtcNow;

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, _clientId),
            new Claim(JwtRegisteredClaimNames.Iss, _clientId),
            new Claim(JwtRegisteredClaimNames.Aud, _tokenEndpoint),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new Claim(JwtRegisteredClaimNames.Iat, new DateTimeOffset(now).ToUnixTimeSeconds().ToString(), ClaimValueTypes.Integer64),
        };

        var token = new JwtSecurityToken(
            claims: claims,
            expires: now.AddMinutes(5),
            signingCredentials: _signingCredentials
        );

        var handler = new JwtSecurityTokenHandler();
        var jwt = handler.WriteToken(token);

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
var builder = WebApplication.CreateBuilder(args);

var rsaKey = RSA.Create();
rsaKey.ImportFromPem(builder.Configuration["ClientAssertion:PrivateKeyPem"]);
var signingCredentials = new SigningCredentials(
    new RsaSecurityKey(rsaKey), SecurityAlgorithms.RsaSsaPssSha256);

builder.Services.AddSingleton<IClientAssertionService>(
    new JwtClientAssertionService(
        signingCredentials,
        clientId: "webapp",
        tokenEndpoint: "https://sts.example.com/connect/token"));

builder.Services.AddAccessTokenManagement();

var app = builder.Build();
app.Run();
```

## Explanation

- The service creates a signed JWT with the client ID as both issuer and subject
- The audience is set to the token endpoint URL
- The JWT is signed with an RSA key loaded from configuration
- The assertion type is set to `urn:ietf:params:oauth:client-assertion-type:jwt-bearer` per RFC 7523
- Register as a singleton since it only needs the signing credentials
