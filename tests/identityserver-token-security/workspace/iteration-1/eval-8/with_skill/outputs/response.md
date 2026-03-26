# Client-Side DPoP with Duende.AccessTokenManagement

Duende.AccessTokenManagement handles DPoP proof token generation automatically. You configure it with a DPoP JWK and it manages proof creation for every token request.

## Configuration

```csharp
using Microsoft.IdentityModel.Tokens;
using System.Security.Cryptography;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

// Generate a DPoP proof key (RSA with PS256)
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jsonWebKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jsonWebKey.Alg = "PS256";
var dpopKey = JsonSerializer.Serialize(jsonWebKey);

// Configure client credentials token management with DPoP
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("dpop_client", client =>
    {
        client.TokenEndpoint = "https://identity.example.com/connect/token";
        client.ClientId = "dpop_client";
        client.ClientSecret = "secret";
        client.DPoPJsonWebKey = dpopKey;
    });

// Register named HttpClient that uses the DPoP-bound token
builder.Services.AddClientCredentialsHttpClient("dpop_api_client",
    configureClient: httpClient =>
    {
        httpClient.BaseAddress = new Uri("https://api.example.com");
    })
    .SetTokenName("dpop_client");

var app = builder.Build();
app.Run();
```

## DPoP JWK Generation

```csharp
// Generate an RSA key pair
var rsaKey = new RsaSecurityKey(RSA.Create(2048));

// Convert to JWK format
var jsonWebKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);

// Set the algorithm — PS256 is recommended for FAPI 2.0
jsonWebKey.Alg = "PS256";

// Serialize to JSON string
string jwk = JsonSerializer.Serialize(jsonWebKey);
```

This generates a full RSA key pair (public + private) as a JWK. The `DPoPJsonWebKey` property expects this serialized JWK string containing **both** public and private key components.

## Critical Security Warnings

**The `DPoPJsonWebKey` is a critical secret:**

- **Losing it**: If you lose the DPoP key, any tokens bound to it become unusable. The client cannot create valid DPoP proofs without the private key, so APIs will reject the tokens.
- **Leaking it**: If the key is compromised, an attacker can generate valid DPoP proofs for any token bound to that key, completely nullifying the security benefits of DPoP.

### Key Management Best Practices
- Persist the key securely (e.g., Azure Key Vault, HashiCorp Vault, DPAPI)
- Rotate keys periodically
- Do not log or include the JWK in diagnostics
- Generate per-instance keys in production (avoid sharing across servers unless necessary)

## How It Works

1. `AddClientCredentialsTokenManagement` manages token acquisition and caching
2. When a token is needed, the library requests one from the token endpoint with a DPoP proof JWT in the `DPoP` header
3. The proof is signed with the private key from `DPoPJsonWebKey`
4. IdentityServer validates the proof and returns a DPoP-bound access token
5. On subsequent API calls, the library automatically generates fresh DPoP proofs for each request
