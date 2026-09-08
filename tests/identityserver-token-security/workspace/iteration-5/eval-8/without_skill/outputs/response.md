# Client-side DPoP with `Duende.AccessTokenManagement`

`Duende.AccessTokenManagement` can manage DPoP for you on the client side — it acquires the token and generates a signed DPoP proof for each request automatically, as long as you give it a DPoP key.

## Package

```bash
dotnet add package Duende.AccessTokenManagement
```

## Configure the client-credentials client with a DPoP key

```csharp
var builder = WebApplication.CreateBuilder(args);

string dpopJwk = CreateDPoPKey();

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("dpop_client", client =>
    {
        client.TokenEndpoint = "https://identity.example.com/connect/token";
        client.ClientId = "dpop_client";
        client.ClientSecret = "secret";
        client.Scope = "api1";

        // Providing a DPoP JWK enables DPoP for this client
        client.DPoPJsonWebKey = dpopJwk;
    });

var app = builder.Build();
app.Run();
```

Then request a typed/named `HttpClient` associated with that client, and every call will carry a DPoP-bound token plus a matching proof.

## Generating a DPoP JWK

A common and efficient choice for DPoP is an elliptic-curve key with ES256:

```csharp
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;

static string CreateDPoPKey()
{
    var ecdsa = ECDsa.Create(ECCurve.NamedCurves.nistP256);
    var key = new ECDsaSecurityKey(ecdsa);

    var jwk = JsonWebKeyConverter.ConvertFromECDsaSecurityKey(key);
    jwk.Alg = "ES256";

    return JsonSerializer.Serialize(jwk);
}
```

The serialized JWK (which contains the private key) is what you pass to `client.DPoPJsonWebKey`.

## Managing the DPoP key

Treat the DPoP JWK as a sensitive secret:

- **Keep it persistent.** Tokens issued are bound to this key, so if you throw the key away (for example by generating a new one on every startup), previously issued tokens can no longer be used because the proof won't match.
- **Keep it private.** If the private key leaks, someone else can produce valid DPoP proofs, which defeats the purpose of DPoP.

For production, store the JWK in a secure store such as a key vault and load it at startup rather than generating it inline.
