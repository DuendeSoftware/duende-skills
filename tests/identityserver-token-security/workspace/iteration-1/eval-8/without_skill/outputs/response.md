# Client-Side DPoP with Duende.AccessTokenManagement

Duende.AccessTokenManagement provides built-in support for DPoP. You configure a DPoP JSON Web Key on the client registration and the library handles creating DPoP proofs automatically.

## Setup

```bash
dotnet add package Duende.AccessTokenManagement
```

## Configuration

```csharp
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Generate a DPoP key
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jsonWebKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jsonWebKey.Alg = "PS256";
string dpopJwk = JsonSerializer.Serialize(jsonWebKey);

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("my_dpop_client", client =>
    {
        client.TokenEndpoint = "https://identity.example.com/connect/token";
        client.ClientId = "dpop_client";
        client.ClientSecret = "secret";
        client.DPoPJsonWebKey = dpopJwk;
    });

// Register an HttpClient that uses the DPoP token
builder.Services.AddClientCredentialsHttpClient("api_client", "my_dpop_client", client =>
{
    client.BaseAddress = new Uri("https://api.example.com");
});

var app = builder.Build();

app.MapGet("/call-api", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("api_client");
    return await client.GetStringAsync("/protected");
});

app.Run();
```

## Generating a DPoP JWK

```csharp
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jsonWebKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jsonWebKey.Alg = "PS256"; // PS256 is recommended for FAPI compliance
string jwk = JsonSerializer.Serialize(jsonWebKey);
```

You can also use ECDSA:

```csharp
var ecKey = new ECDsaSecurityKey(ECDsa.Create(ECCurve.NamedCurves.nistP256));
var jsonWebKey = JsonWebKeyConverter.ConvertFromSecurityKey(ecKey);
jsonWebKey.Alg = "ES256";
string jwk = JsonSerializer.Serialize(jsonWebKey);
```

## How It Works

1. `AddClientCredentialsTokenManagement` sets up the token management infrastructure.
2. `AddClient` registers a named client configuration with DPoP enabled via `DPoPJsonWebKey`.
3. When tokens are requested, the library automatically creates signed DPoP proofs and sends them in the `DPoP` header.
4. The `AddClientCredentialsHttpClient` creates an HttpClient that attaches DPoP tokens to API calls automatically.
