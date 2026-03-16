# DPoP with Client Credentials

DPoP (Demonstrating Proof-of-Possession) binds tokens to a client key. Here's how to set it up:

```csharp
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Generate RSA key for DPoP
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jwk = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jwk.Alg = "PS256";
var jwkJson = System.Text.Json.JsonSerializer.Serialize(jwk);

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog-client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = "catalog-worker";
        client.ClientSecret = "worker-secret";
        client.Scope = "catalog:read";
        client.DPoPJsonWebKey = jwkJson;
    });

var app = builder.Build();
app.Run();
```

This generates an RSA key pair and configures it for DPoP-bound tokens.
