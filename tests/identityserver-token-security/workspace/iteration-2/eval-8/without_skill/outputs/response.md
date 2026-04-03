# Client-Side DPoP Configuration

DPoP (Demonstrating Proof of Possession) requires the client to generate a key pair and include a proof token with each request. Here's how to set it up:

## Generating a DPoP Key

```csharp
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;
using System.Text.Json;

// Generate an RSA key pair for DPoP
var rsa = RSA.Create(2048);
var rsaKey = new RsaSecurityKey(rsa);
var jwk = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jwk.Alg = "RS256";

string dpopKey = JsonSerializer.Serialize(jwk);
```

## Requesting a Token with DPoP

You'll need to create a DPoP proof JWT and include it in the token request:

```csharp
var client = new HttpClient();

var tokenRequest = new HttpRequestMessage(HttpMethod.Post, "https://identity.example.com/connect/token");
tokenRequest.Content = new FormUrlEncodedContent(new Dictionary<string, string>
{
    ["grant_type"] = "client_credentials",
    ["client_id"] = "dpop_client",
    ["client_secret"] = "secret",
    ["scope"] = "api1"
});

// Add DPoP proof header
tokenRequest.Headers.Add("DPoP", CreateDPoPProof(dpopKey, "POST", "https://identity.example.com/connect/token"));

var response = await client.SendAsync(tokenRequest);
```

## Creating the DPoP Proof

The DPoP proof is a JWT signed with your private key that includes:
- `htm` - HTTP method
- `htu` - HTTP URI
- `iat` - Issued at time
- `jti` - Unique identifier

You'd need to implement `CreateDPoPProof` to sign a JWT with these claims.

## Notes

- The key must be persisted securely — if you lose it, tokens bound to it can't be used
- Consider using a library that handles DPoP proof creation automatically
- For production, store the key in a secure key store
