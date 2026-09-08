# Client-side DPoP with `Duende.AccessTokenManagement`

`Duende.AccessTokenManagement` handles the whole DPoP proof-token lifecycle for you: it signs a fresh proof JWT with your DPoP key on every token request and every API call, manages nonces, and refreshes tokens. You just supply the DPoP key as a JWK string.

## Package

```bash
dotnet add package Duende.AccessTokenManagement
```

## Register the client-credentials client with a DPoP key

Use `AddClientCredentialsTokenManagement().AddClient(...)` and set `DPoPJsonWebKey` on the client options:

```csharp
var builder = WebApplication.CreateBuilder(args);

// Generate (or load) the DPoP JWK — see below
string dpopJwk = CreateDPoPKey();

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("demo_dpop_client", client =>
    {
        client.TokenEndpoint = "https://identity.example.com/connect/token";
        client.ClientId = "dpop_client";
        client.ClientSecret = "secret";
        client.Scope = "api1";

        // Supplying the JWK turns on DPoP for this client.
        client.DPoPJsonWebKey = dpopJwk;
    });

// Then resolve an HttpClient bound to that client, e.g.:
builder.Services.AddClientCredentialsHttpClient("api-client", "demo_dpop_client", cfg =>
{
    cfg.BaseAddress = new Uri("https://api.example.com");
});

var app = builder.Build();
app.Run();
```

Any `HttpClient` wired to the `demo_dpop_client` will automatically obtain a DPoP-bound access token and attach a matching DPoP proof on each outbound request.

## Generating a suitable DPoP JWK

DPoP proofs should use an asymmetric algorithm; here an RSA key with **PS256**. Convert the security key to a JWK and set its `Alg`:

```csharp
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;

static string CreateDPoPKey()
{
    // 2048-bit RSA key
    var rsaKey = new RsaSecurityKey(RSA.Create(2048));

    // Convert to a JWK
    var jsonWebKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);

    // DPoP proof signing algorithm
    jsonWebKey.Alg = "PS256";

    // Serialize the JWK (this is what DPoPJsonWebKey expects)
    return JsonSerializer.Serialize(jsonWebKey);
}
```

The resulting string (including the private key material) is what you assign to `client.DPoPJsonWebKey`.

## ⚠️ DPoP key management warning

The `DPoPJsonWebKey` is a **critical secret**, and it behaves differently from an ordinary client secret:

- **It must persist** for the lifetime of any token bound to it. If you regenerate or lose the key, every access token bound to the old key becomes **unusable** — APIs will reject the proofs because the thumbprint no longer matches.
- **It must stay secret.** If the key leaks, an attacker can forge valid DPoP proofs, which **nullifies the entire security benefit** of DPoP (the token is no longer effectively bound to you alone).

So don't generate a throwaway key on every startup for production. Store the JWK in a durable, protected location (e.g. a secrets manager / key vault) and load it, so bound tokens remain valid and the private key is never exposed.
