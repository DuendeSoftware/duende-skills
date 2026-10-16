# Enabling DPoP for `dpop_client`

## What DPoP does
DPoP (Demonstrating Proof-of-Possession at the application layer, RFC 9449) turns bearer tokens into **sender-constrained** tokens. The client holds an asymmetric key (a JWK) and sends a signed proof JWT in the `DPoP` HTTP header on every request. IdentityServer binds the access token to that key via the `cnf` claim:

```json
{ "cnf": { "jkt": "JGSVlE73oKtQQI1dypYg8_JNat0xJjsQNyOI5oxaZf4" } }
```

A leaked token is useless without the private key. DPoP is separate from client authentication: `dpop_client` can keep its shared secret for authentication while DPoP binds the token. (DPoP requires Enterprise Edition, version ≥ 6.3.)

## Client configuration (add to `Config.Clients`)

```csharp
new Client
{
    ClientId = "dpop_client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },

    RequireDPoP = true,                       // token requests must include a DPoP proof

    // Proof expiration validation: Iat (default), Nonce, or both
    DPoPValidationMode = DPoPTokenExpirationValidationMode.Iat,

    // Clock skew for iat validation (default 5 minutes)
    DPoPClockSkew = TimeSpan.FromMinutes(2)
}
```

| Property | Default | Purpose |
|---|---|---|
| `RequireDPoP` | `false` | Require DPoP for this client |
| `DPoPValidationMode` | `Iat` | Validate via client `iat` and/or server nonce |
| `DPoPClockSkew` | 5 min | Skew allowed on the `iat` claim |

## Client side
Use `Duende.AccessTokenManagement`, which creates proofs and handles nonces automatically:

```csharp
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("dpop_client", client =>
    {
        client.TokenEndpoint = "https://identity.example.com/connect/token";
        client.ClientId = "dpop_client";
        client.ClientSecret = "secret";
        client.DPoPJsonWebKey = "..."; // JWK string
    });
```

Treat the `DPoPJsonWebKey` as a critical secret: if lost, tokens bound to it become unusable; if leaked, DPoP's protection is lost. Your APIs must also validate DPoP (`Duende.AspNetCore.Authentication.JwtBearer` + `ConfigureDPoPTokensForScheme`), otherwise the binding is not enforced.
