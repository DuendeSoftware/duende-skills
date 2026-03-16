# Client-Side DPoP with Duende.AccessTokenManagement

Duende.AccessTokenManagement handles DPoP proof token creation and management automatically. For client credentials flow, you configure the DPoP JWK on the client registration and the library handles proof generation on every token request and API call.

## Install the Package

```bash
dotnet add package Duende.AccessTokenManagement
```

## Configuration

```csharp
// Program.cs
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Generate a DPoP JWK (see below for key generation)
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jsonWebKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jsonWebKey.Alg = "PS256";
string dpopJwk = JsonSerializer.Serialize(jsonWebKey);

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("demo_dpop_client", client =>
    {
        client.TokenEndpoint = "https://identity.example.com/connect/token";
        client.ClientId = "dpop_client";
        client.ClientSecret = "secret";
        client.DPoPJsonWebKey = dpopJwk;
    });

// Register named HttpClient that automatically attaches DPoP tokens
builder.Services.AddClientCredentialsHttpClient("api_client", "demo_dpop_client", client =>
{
    client.BaseAddress = new Uri("https://api.example.com");
});

var app = builder.Build();

app.MapGet("/call-api", async (IHttpClientFactory factory) =>
{
    var client = factory.CreateClient("api_client");
    var response = await client.GetStringAsync("/protected");
    return response;
});

app.Run();
```

## Generating a DPoP JWK

```csharp
// Generate an RSA key pair for DPoP
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jsonWebKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jsonWebKey.Alg = "PS256"; // Use PS256 for FAPI 2.0 compliance
string jwk = JsonSerializer.Serialize(jsonWebKey);

// Store this JWK securely — it contains both public and private key material
Console.WriteLine(jwk);
```

You can also use ECDSA keys:

```csharp
var ecKey = new ECDsaSecurityKey(ECDsa.Create(ECCurve.NamedCurves.nistP256));
var jsonWebKey = JsonWebKeyConverter.ConvertFromSecurityKey(ecKey);
jsonWebKey.Alg = "ES256";
string jwk = JsonSerializer.Serialize(jsonWebKey);
```

## Critical Security Warning

The `DPoPJsonWebKey` is a **critical secret** that requires careful management:

- **If lost**: Tokens bound to this key become unusable — the client cannot produce valid DPoP proofs for existing tokens, and those tokens will be rejected by APIs.
- **If leaked**: The security benefits of DPoP are completely nullified — an attacker with the key can produce valid proofs for any stolen tokens, defeating proof-of-possession.

Store the JWK in a secure location (Azure Key Vault, AWS Secrets Manager, HashiCorp Vault, etc.). Do not hardcode it in source code or configuration files. In production, persist the key across application restarts so existing tokens remain valid.

## How It Works

1. `AddClientCredentialsTokenManagement` registers the token management infrastructure.
2. `AddClient` configures a named client with the token endpoint, credentials, and DPoP key.
3. When a token is requested, the library automatically creates a DPoP proof JWT signed with the private key and sends it in the `DPoP` header.
4. The library caches the access token and handles refresh when it expires.
5. When using the named `HttpClient` via `AddClientCredentialsHttpClient`, the library attaches the `DPoP` authorization header with the access token and includes a fresh DPoP proof on every API call.

## Authorization Code Flow

For interactive flows, configure DPoP on the OpenID Connect token management:

```csharp
builder.Services.AddAuthentication(...)
    .AddCookie("cookie", ...)
    .AddOpenIdConnect("oidc", ...);

builder.Services.AddOpenIdConnectAccessTokenManagement(options =>
{
    options.DPoPJsonWebKey = dpopJwk;
});
```
