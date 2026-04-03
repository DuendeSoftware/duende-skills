# Enabling DPoP for a Client Credentials Client

## What is DPoP?

DPoP (Demonstrating Proof-of-Possession) binds an access token to an asymmetric key held by the client. The token contains a `cnf` (confirmation) claim with a `jkt` (JWK Thumbprint) value:

```json
{
  "cnf": {
    "jkt": "JGSVlE73oKtQQI1dypYg8_JNat0xJjsQNyOI5oxaZf4"
  }
}
```

On every request to an API, the client must send a `DPoP` HTTP header containing a signed JWT proof token. This proves the client possesses the private key corresponding to the `jkt` thumbprint. If the token leaks, an attacker cannot use it without the private key.

**DPoP requires Enterprise Edition and Duende IdentityServer version >= 6.3.**

## Client Configuration

DPoP is separate from client authentication. The client still authenticates with its shared secret at the token endpoint — DPoP only constrains the resulting access token.

```csharp
new Client
{
    ClientId = "dpop_client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "api1" },

    // Enable DPoP
    RequireDPoP = true,

    // Control DPoP proof token clock skew (default is 5 minutes)
    DPoPClockSkew = TimeSpan.FromMinutes(2)
}
```

### Key points:

- **`RequireDPoP = true`** — Forces this client to provide a DPoP proof on every token request. Without it, the token endpoint rejects the request.
- **`DPoPClockSkew = TimeSpan.FromMinutes(2)`** — Controls how much clock drift is tolerated when validating the `iat` claim in DPoP proof tokens. The default is 5 minutes; setting it to 2 minutes tightens the window.
- The client still uses `GrantTypes.ClientCredentials` with a shared secret for authentication. DPoP is an additional layer that binds the issued token to the client's proof key — it does not replace client authentication.

### Updated Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "dpop_client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" },
            RequireDPoP = true,
            DPoPClockSkew = TimeSpan.FromMinutes(2)
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```
