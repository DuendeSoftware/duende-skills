# Adding DPoP to Client Credentials Token Management

DPoP binds the access token to a client-held asymmetric key, so a stolen token can't be replayed without the private key. The key must be **stable** — loaded from configuration/secure storage, not regenerated on each start. Regenerating it invalidates every previously issued DPoP-bound token.

## Load the JWK from configuration (not ephemeral)

Your JWK lives at `DPoP:JsonWebKey`. Read it from configuration and set it on the client:

```csharp
using Duende.AccessTokenManagement;

var builder = WebApplication.CreateBuilder(args);

// ✅ Load the JWK from configuration / secret store — stable across restarts
var dpopJwk = builder.Configuration["DPoP:JsonWebKey"];
if (string.IsNullOrWhiteSpace(dpopJwk))
{
    throw new InvalidOperationException("DPoP:JsonWebKey is not configured.");
}

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId     = ClientId.Parse("catalog-worker");
        client.ClientSecret = ClientSecret.Parse("worker-secret");
        client.Scope        = Scope.Parse("catalog:read");

        // ✅ Bind tokens for this client to the DPoP key
        client.DPoPJsonWebKey = dpopJwk;
    });

builder.Services.AddClientCredentialsHttpClient(
    "catalog",
    ClientCredentialsClientName.Parse("catalog.client"),
    configureClient: client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/catalog/");
    });
```

Once `DPoPJsonWebKey` is set, the library automatically:
- sends a DPoP proof on every token endpoint call (including refreshes), and
- sends a DPoP proof on every outgoing API call made through the factory client.

## ❌ What NOT to do — ephemeral keys

```csharp
// ❌ New key on every process restart — all previously issued DPoP-bound tokens
//    become unusable, causing 401s until fresh tokens are obtained
var rsaKey = new RsaSecurityKey(RSA.Create(2048)); // lost on restart
```

Generate the JWK **once**, store it securely (Key Vault / configuration secrets), and load it as shown above.

### Generating the key once (offline / provisioning step)

```csharp
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;

var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jwkKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jwkKey.Alg = "PS256";
var jwk = JsonSerializer.Serialize(jwkKey); // store this at DPoP:JsonWebKey
```

Supported algorithms are the RS, PS, and ES families.

## Optional: dynamic key resolution with `IDPoPKeyStore`

If you need to rotate or resolve the key at runtime rather than at startup, implement `IDPoPKeyStore`:

```csharp
public sealed class KeyVaultDPoPKeyStore(IKeyVaultClient keyVault) : IDPoPKeyStore
{
    public async Task<string?> GetKeyAsync(string clientName, CancellationToken ct)
        => await keyVault.GetSecretAsync($"dpop-key-{clientName}", ct);
}

// Registration
services.AddSingleton<IDPoPKeyStore, KeyVaultDPoPKeyStore>();
```

> **Note (user-token DPoP):** if you were doing this for `AddOpenIdConnectAccessTokenManagement`, the DPoP proof key is stored per user session in the OIDC `state` and auth cookie, which increases their size — consider `SessionStore`/`StateDataFormat` tuning. For the client-credentials worker case above, that doesn't apply.
