## Pattern 5: DPoP (Demonstrating Proof-of-Possession)

DPoP binds an access token to an asymmetric key so that the token cannot be replayed by an attacker who steals it — they would also need the private key. This pattern extends the core `token-management` skill.

### Generate a JWK

```csharp
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;

// ✅ Generate once and store securely (Key Vault, configuration secrets)
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jwkKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jwkKey.Alg = "PS256";
var jwk = JsonSerializer.Serialize(jwkKey);
```

Supported algorithms: RS, PS, and ES family keys (any JWK-compatible asymmetric key).

### Configure DPoP — User Token (OpenIdConnect)

```csharp
// ✅ Set the JWK at startup; the library handles everything else automatically
builder.Services.AddOpenIdConnectAccessTokenManagement(options =>
{
    options.DPoPJsonWebKey = jwk;
});
```

The library automatically:
- Adds `dpop_jkt` to the authorize endpoint request
- Sends a DPoP proof token on every token endpoint call (including token refreshes)
- Sends a DPoP proof token on every outgoing API call made via factory clients

### Configure DPoP — Client Credentials

```csharp
// ✅ Per-client DPoP key
services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.company.com/connect/token");
        client.ClientId = ClientId.Parse("...");
        client.ClientSecret = ClientSecret.Parse("...");
        client.DPoPJsonWebKey = jwk;
    });
```

### Custom DPoP Key Store

Implement `IDPoPKeyStore` to load or rotate the key at runtime rather than at startup:

```csharp
// ✅ Dynamic key resolution (e.g., from Azure Key Vault)
public sealed class KeyVaultDPoPKeyStore : IDPoPKeyStore
{
    private readonly IKeyVaultClient _keyVault;

    public KeyVaultDPoPKeyStore(IKeyVaultClient keyVault)
    {
        _keyVault = keyVault;
    }

    public async Task<string?> GetKeyAsync(string clientName, CancellationToken ct)
    {
        return await _keyVault.GetSecretAsync($"dpop-key-{clientName}", ct);
    }
}

// Registration
services.AddSingleton<IDPoPKeyStore, KeyVaultDPoPKeyStore>();
```

> **DPoP and user session size** — When using DPoP with `AddOpenIdConnectAccessTokenManagement`, the DPoP proof key is stored per user session inside the OIDC `state` parameter and the authentication cookie. This increases cookie and state size. Configure `StateDataFormat` on the OIDC options and `SessionStore` on the cookie options if this becomes a concern.

### Pitfall: Regenerating DPoP Keys on Every Process Restart

```csharp
// ❌ New key generated on every restart — all previously issued DPoP-bound tokens
// become unusable, causing 401 errors until new tokens are obtained
var rsaKey = new RsaSecurityKey(RSA.Create(2048)); // ephemeral — lost on restart

// ✅ Load from stable, secure storage
var jwkJson = configuration["DPoP:JsonWebKey"]; // from Key Vault / secrets
services.AddClientCredentialsTokenManagement()
    .AddClient("my.client", client =>
    {
        client.DPoPJsonWebKey = jwkJson;
    });
```

### Combining DPoP With Custom OpenID Connect Events

`AddOpenIdConnectAccessTokenManagement` registers an `IConfigureNamedOptions<OpenIdConnectOptions>` that wraps these events (your handler runs first, then the library's):

| Event | Purpose |
|-------|---------|
| `OnRedirectToIdentityProvider` | Adds `dpop_jkt` and stores the DPoP key in the authentication properties |
| `OnAuthorizationCodeReceived` | Makes the DPoP key available for the code exchange; adds the client assertion if configured |
| `OnTokenValidated` | Reserved for DPoP key handling |
| `OnPushAuthorization` | Adds the client assertion to the PAR request (.NET 9+) |

- **Wrap, don't replace**: assigning `options.Events` handlers (or a new `OpenIdConnectEvents`) after the library configured them, e.g. in an `IPostConfigureOptions<OpenIdConnectOptions>`, discards the DPoP handlers unless you capture and invoke the existing ones.
- **Don't use `OpenIdConnectOptions.EventsType`**: ASP.NET Core then uses that type instead of `Events`, silently removing all library handlers. Sign-in still succeeds, but `dpop_jkt` isn't sent and the code isn't exchanged with the DPoP key.
- **JAR + DPoP + PAR**: without PAR, wrap `OnRedirectToIdentityProvider` (call the library's handler first so `dpop_jkt` is added, then sign all parameters and keep `client_id`/`redirect_uri`); only sign there when PAR is not actually used (with `PushedAuthorizationBehavior.UseIfAvailable` the handler falls back to a redirect if discovery has no PAR endpoint). With PAR (.NET 9+), wrap `OnPushAuthorization`: sign all parameters (including `dpop_jkt`) first, then call the library's handler to add the client assertion.

### Related Resources

- [Advanced: DPoP](https://docs.duendesoftware.com/accesstokenmanagement/advanced/dpop/)
- Server-side DPoP validation: see `identityserver-token-security` skill
