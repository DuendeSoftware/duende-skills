# DPoP client side with Duende.AccessTokenManagement

```
dotnet add package Duende.AccessTokenManagement
```

```csharp
builder.Services.AddDistributedMemoryCache();

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("dpop.client", client =>
    {
        client.TokenEndpoint = new Uri("https://identity.example.com/connect/token");
        client.ClientId = ClientId.Parse("dpop_client");
        client.ClientSecret = ClientSecret.Parse("secret");
        client.Scope = Scope.Parse("api1");
        client.DPoPJsonWebKey = DPoPProofKey.Parse(jwk);   // string JWK (private key)
    });

builder.Services.AddClientCredentialsHttpClient("api", "dpop.client", c =>
    c.BaseAddress = new Uri("https://api.example.com"));
```

(Older versions: `ClientCredentialsClient` options with `DPoPJsonWebKey = jwk`.) The library creates DPoP proofs, handles `DPoP-Nonce` challenges and retries, and sends `Authorization: DPoP <token>`. Store the key in config/Key Vault, not in source.

## Generating a JWK

```csharp
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jwk = JsonWebKeyConverter.ConvertFromRSASecurityKey(rsaKey);
jwk.Alg = "PS256";
string json = JsonSerializer.Serialize(jwk);
```

An EC key (ES256) is smaller and recommended:

```csharp
var ec = ECDsa.Create(ECCurve.NamedCurves.nistP256);
var key = new ECDsaSecurityKey(ec);
var jwk = JsonWebKeyConverter.ConvertFromECDsaSecurityKey(key);
jwk.Alg = "ES256";
```
The JWK contains the private parameters — keep it secret. Rotate when needed; tokens are bound to the key, so a new key requires new tokens.
