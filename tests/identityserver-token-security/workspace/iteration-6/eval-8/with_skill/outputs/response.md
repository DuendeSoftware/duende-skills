# DPoP client side with Duende.AccessTokenManagement

## Client credentials configuration

```csharp
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("demo_dpop_client", client =>
    {
        client.TokenEndpoint = "https://identity.example.com/connect/token";
        client.ClientId = "dpop_client";
        client.ClientSecret = "secret";
        client.Scope = "api1";
        client.DPoPJsonWebKey = "..."; // JWK string (private key)
    });
```

For authorization code flow, use `AddOpenIdConnectAccessTokenManagement(options => options.DPoPJsonWebKey = "...")`.

The library creates the proofs, sends `Authorization: DPoP <token>`, and handles server nonces.

## Generating the JWK

```csharp
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jsonWebKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jsonWebKey.Alg = "PS256";
string jwk = JsonSerializer.Serialize(jsonWebKey);
```

Store `jwk` in a secret store (Key Vault etc.), not in source control.

## Key management
The `DPoPJsonWebKey` is a critical secret: it must persist for the lifetime of tokens bound to it. If lost, bound tokens can't be used; if leaked, DPoP's benefits are lost.

## Server side
The client must be allowed to use DPoP — the server supports it dynamically, or you can enforce it with `RequireDPoP = true` on the client (Enterprise Edition, ≥ 6.3). The client authenticates with its secret as usual; DPoP is independent of client authentication.
