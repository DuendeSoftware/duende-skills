# Client-Side DPoP with Duende.AccessTokenManagement

## Setup for Client Credentials Flow

```csharp
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Generate a DPoP JWK (RSA 2048-bit with PS256)
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jsonWebKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jsonWebKey.Alg = "PS256";
string dpopJwk = JsonSerializer.Serialize(jsonWebKey);

// Configure client credentials token management with DPoP
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("demo_dpop_client", client =>
    {
        client.TokenEndpoint = "https://identity.example.com/connect/token";
        client.ClientId = "dpop_client";
        client.ClientSecret = "secret";
        client.DPoPJsonWebKey = dpopJwk;
    });

// Register an HTTP client that uses the managed DPoP tokens
builder.Services.AddClientCredentialsHttpClient("api_client", "demo_dpop_client", client =>
{
    client.BaseAddress = new Uri("https://api.example.com");
});

var app = builder.Build();

app.MapGet("/call-api", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("api_client");
    var response = await client.GetStringAsync("/data");
    return response;
});

app.Run();
```

## Generating a DPoP JWK

```csharp
// Generate an RSA key pair
var rsaKey = new RsaSecurityKey(RSA.Create(2048));

// Convert to JWK format
var jsonWebKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jsonWebKey.Alg = "PS256";  // Set the signing algorithm

// Serialize to JSON string for DPoPJsonWebKey
string jwk = JsonSerializer.Serialize(jsonWebKey);
```

The JWK string contains both the public and private key material. The library uses the private key to sign DPoP proof tokens, and the server sees the public key in the proof.

## How It Works

1. `AddClientCredentialsTokenManagement` handles token acquisition, caching, and renewal
2. Setting `DPoPJsonWebKey` enables DPoP proof generation — the library automatically creates and signs a DPoP proof JWT for each token request and API call
3. The `DPoP` HTTP header is added to every request, proving possession of the private key
4. The access token's `cnf` claim contains the JWK thumbprint, binding it to the key

## Critical: DPoP Key Management

**The `DPoPJsonWebKey` is a critical secret:**

- **If lost**: Tokens bound to this key become unusable. The client cannot create valid DPoP proofs, and APIs will reject the tokens.
- **If leaked**: An attacker with both the token and the key can create valid DPoP proofs, completely nullifying DPoP's security benefit.

In production:
- Store the DPoP key securely (Key Vault, HSM, encrypted storage)
- Persist it across application restarts — if the key changes, all outstanding tokens become invalid
- Rotate the key carefully, ensuring all bound tokens have expired before discarding the old key
- Never log or expose the serialized JWK
