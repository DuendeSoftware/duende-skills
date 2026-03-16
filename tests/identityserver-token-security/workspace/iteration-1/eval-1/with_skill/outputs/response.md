# Enabling DPoP for a Client Credentials Client

DPoP (Demonstrating Proof-of-Possession at the Application Layer) binds an access token to an asymmetric key held by the client. The token includes a `cnf` claim with a `jkt` (JWK Thumbprint) value — the SHA-256 thumbprint of the client's public key. On every API call, the client must send a signed DPoP proof JWT in the `DPoP` HTTP header, proving it holds the private key that matches the thumbprint in the token.

This is fundamentally different from client authentication. DPoP proves token *possession* at the application layer, while client authentication (shared secret, private_key_jwt, mTLS) proves client *identity* at the token endpoint. A client can use a shared secret for authentication and DPoP for token binding simultaneously.

**Important:** DPoP requires **Duende IdentityServer Enterprise Edition**, version **>= 6.3**.

## Updated Client Configuration

```csharp
// Program.cs
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "dpop_client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" },

            // Require DPoP proof-of-possession for this client
            RequireDPoP = true,

            // Control clock skew for DPoP proof token iat validation
            DPoPClockSkew = TimeSpan.FromMinutes(2)
        }
    ];
}
```

## How DPoP Works

1. The client generates an asymmetric key pair (RSA or ECDSA) and stores it as a JWK.
2. When requesting a token, the client sends a DPoP proof JWT in the `DPoP` header — signed with the private key, containing the HTTP method, URL, and a unique `jti`.
3. IdentityServer validates the proof and embeds the public key's thumbprint in the access token via the `cnf` claim:
   ```json
   {
     "cnf": {
       "jkt": "JGSVlE73oKtQQI1dypYg8_JNat0xJjsQNyOI5oxaZf4"
     }
   }
   ```
4. When calling an API, the client sends the access token with scheme `DPoP` (not `Bearer`) and includes a fresh DPoP proof JWT.
5. The API validates that the proof's public key matches the `jkt` in the token's `cnf` claim.

If a token leaks, an attacker cannot use it because they don't have the private key to produce valid DPoP proofs.

## Key Points

- `RequireDPoP = true` enforces that this client *must* use DPoP. Without it, DPoP is optional (the client can choose to use it).
- `DPoPClockSkew` controls how much clock drift is allowed when validating the `iat` claim in DPoP proof tokens. The default is 5 minutes.
- The client still authenticates with a shared secret — DPoP is orthogonal to client authentication.
- DPoP is preferred over mTLS for most scenarios because it works at the application layer with no TLS infrastructure changes.
