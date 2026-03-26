# DPoP with Client Credentials Token Management

## Loading the DPoP Key from Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

// Load the DPoP JWK from configuration (e.g., Key Vault, user secrets, env var)
var dpopJwk = builder.Configuration["DPoP:JsonWebKey"];

// Register client credentials with the DPoP key
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient(ClientCredentialsClientName.Parse("my-client"), client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("my-client-id");
        client.ClientSecret = ClientSecret.Parse("my-client-secret");
        client.Scope = Scope.Parse("api1");
        client.DPoPJsonWebKey = dpopJwk;  // DPoP key from configuration
    });

builder.Services.AddClientCredentialsHttpClient(
    "api",
    ClientCredentialsClientName.Parse("my-client"),
    client => client.BaseAddress = new Uri("https://api.example.com/"));
```

## Important: Do NOT Generate Ephemeral Keys

```csharp
// ❌ WRONG: New key generated on every restart
// All previously issued DPoP-bound tokens become unusable, causing 401 errors
var rsaKey = new RsaSecurityKey(RSA.Create(2048)); // ephemeral — lost on restart

// ✅ CORRECT: Load from stable, secure storage
var jwkJson = builder.Configuration["DPoP:JsonWebKey"]; // from Key Vault / secrets
```

When DPoP is configured, the library automatically:
- Sends a DPoP proof JWT with every token endpoint request
- Sends a DPoP proof JWT with every outgoing API request
- Handles DPoP nonce challenges from the server

## Generating a JWK (One-Time Setup)

Generate the JWK once and store it securely:

```csharp
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;

var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jwkKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jwkKey.Alg = "PS256";
var jwk = JsonSerializer.Serialize(jwkKey);
// Store this JWK in Key Vault or configuration secrets
```

## Advanced: Custom Key Store

For dynamic key resolution (e.g., per-client keys from Azure Key Vault), implement `IDPoPKeyStore`:

```csharp
public sealed class KeyVaultDPoPKeyStore : IDPoPKeyStore
{
    public async Task<string?> GetKeyAsync(string clientName, CancellationToken ct)
    {
        return await keyVault.GetSecretAsync($"dpop-key-{clientName}", ct);
    }
}

builder.Services.AddSingleton<IDPoPKeyStore, KeyVaultDPoPKeyStore>();
```
