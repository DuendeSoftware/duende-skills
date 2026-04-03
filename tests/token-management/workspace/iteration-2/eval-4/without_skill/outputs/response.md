# Adding DPoP Support to Client Credentials Token Management

DPoP (Demonstrating Proof-of-Possession) binds tokens to a cryptographic key to prevent token theft/replay. Here's how to set it up.

## `Program.cs`

```csharp
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;
using Duende.AccessTokenManagement;

var builder = WebApplication.CreateBuilder(args);

// Generate a DPoP key
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jwkKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jwkKey.Alg = "PS256";
var dpopJwk = System.Text.Json.JsonSerializer.Serialize(jwkKey);

// Register client credentials with DPoP
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client =>
    {
        client.TokenEndpoint = "https://sts.example.com/connect/token";
        client.ClientId = "catalog-worker";
        client.ClientSecret = "worker-secret";
        client.Scope = "catalog:read";
        client.DPoPJsonWebKey = dpopJwk;
    });

// Register HTTP client
builder.Services.AddHttpClient("catalog-api", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/catalog/");
}).AddClientCredentialsTokenHandler("catalog.client");

var app = builder.Build();
app.Run();
```

## Notes

- DPoP requires setting the `DPoPJsonWebKey` property on the client configuration.
- The RSA key is generated at startup and used for creating DPoP proofs.
- The library handles sending the DPoP proof header automatically when making API calls.
- Make sure the token endpoint and API support DPoP.
