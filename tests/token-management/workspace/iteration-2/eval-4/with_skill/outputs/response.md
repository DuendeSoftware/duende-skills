# Adding DPoP Support to Client Credentials Token Management

Here's how to configure DPoP with Duende.AccessTokenManagement v4, loading the JWK from configuration so it persists across process restarts.

## `Program.cs`

```csharp
using Duende.AccessTokenManagement;

var builder = WebApplication.CreateBuilder(args);

// Load the DPoP JWK from configuration (stored in Key Vault, user secrets, etc.)
// IMPORTANT: Do NOT generate a new RSA key at startup — ephemeral keys are lost on
// restart, causing all previously issued DPoP-bound tokens to become unusable (401 errors).
var dpopJwk = builder.Configuration["DPoP:JsonWebKey"];

// Register client credentials token management with DPoP
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("catalog-worker");
        client.ClientSecret = ClientSecret.Parse("worker-secret");
        client.Scope = Scope.Parse("catalog:read");

        // Set the DPoP JSON Web Key — the library will automatically:
        // - Send a DPoP proof on every token endpoint call
        // - Send a DPoP proof on every outgoing API call via factory clients
        client.DPoPJsonWebKey = dpopJwk;
    });

// Register an HTTP client with automatic DPoP token management
builder.Services.AddClientCredentialsHttpClient(
    "catalog-api",
    ClientCredentialsClientName.Parse("catalog.client"),
    client =>
    {
        client.BaseAddress = new Uri("https://api.example.com/catalog/");
    });

var app = builder.Build();
app.Run();
```

## Generating a JWK (One-Time Setup)

Generate the JWK once and store it in a secure location (Azure Key Vault, AWS Secrets Manager, etc.):

```csharp
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;

// Generate once and store securely
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jwkKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jwkKey.Alg = "PS256";
var jwk = JsonSerializer.Serialize(jwkKey);
// Store `jwk` in Key Vault or configuration secrets
```

## Key Points

1. **Load the JWK from configuration** — The DPoP key is loaded from `Configuration["DPoP:JsonWebKey"]` rather than generating a new one at startup.
2. **`DPoPJsonWebKey`** is set on the client credentials client options, and the library automatically handles DPoP proofs for both token endpoint calls and API calls.
3. **Never use `RSA.Create()` at startup** — Generating an ephemeral key on every process restart means all previously issued DPoP-bound tokens become unusable, causing 401 errors until new tokens are obtained.
4. **For dynamic key resolution**, implement `IDPoPKeyStore` to load or rotate keys at runtime (e.g., from Azure Key Vault):

```csharp
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

// Register it
builder.Services.AddSingleton<IDPoPKeyStore, KeyVaultDPoPKeyStore>();
```
