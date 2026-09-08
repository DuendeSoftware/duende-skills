# Implementing `IClientAssertionService` (private_key_jwt)

To authenticate your client with a signed JWT instead of a shared secret, implement `IClientAssertionService`. Its `GetClientAssertionAsync` method returns a `ClientAssertion` containing a JWT you sign with your private key.

```csharp
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;

public class JwtClientAssertionService : IClientAssertionService
{
    private readonly SigningCredentials _signingCredentials;
    private const string ClientId = "my_client_id";

    public JwtClientAssertionService(SigningCredentials signingCredentials)
    {
        _signingCredentials = signingCredentials;
    }

    public Task<ClientAssertion?> GetClientAssertionAsync(
        string? clientName = null,
        TokenRequestParameters? parameters = null)
    {
        var now = DateTime.UtcNow;

        var token = new JwtSecurityToken(
            issuer: ClientId,
            audience: "https://identity.example.com/connect/token", // the token endpoint
            claims: new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, ClientId),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            },
            notBefore: now,
            expires: now.AddMinutes(5),
            signingCredentials: _signingCredentials);

        var jwt = new JwtSecurityTokenHandler().WriteToken(token);

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
builder.Services.AddSingleton<IClientAssertionService, JwtClientAssertionService>();
```

## About the audience and the CVE

The `aud` (audience) claim identifies the authorization server that is the intended recipient of the assertion. Per RFC 7523 the audience is commonly set to the token endpoint URL of the authorization server, which is what the example above uses.

There have been reported vulnerabilities around client-assertion audience validation where a mismatch or overly-permissive audience check let assertions be replayed against the wrong endpoint. To stay safe:

- Use a **short lifetime** (a few minutes) and a unique `jti` on every assertion to limit replay.
- Make sure the value you put in `aud` exactly matches what your authorization server expects and validates — check its documentation, since some servers expect the issuer URL and others the token endpoint URL.
- Keep your library patched to a version that includes the fix for the reported CVE.

Because the exact expected audience value differs by server and was the subject of a security advisory, confirm the required value against your identity provider's current guidance before deploying.
