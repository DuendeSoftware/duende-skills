# DPoP with Client Credentials — Loading Key from Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

// Load the DPoP JWK from configuration (not generated ephemerally)
var dpopJwk = builder.Configuration["DPoP:JsonWebKey"];

// WARNING: Do NOT generate a new RSA key at startup like this:
//   var rsaKey = new RsaSecurityKey(RSA.Create(2048)); // ephemeral — lost on restart
// All previously issued DPoP-bound tokens become unusable if the key changes.
// Always load from stable, secure storage (Key Vault, configuration secrets).

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse("catalog-worker");
        client.ClientSecret = ClientSecret.Parse("worker-secret");
        client.Scope = Scope.Parse("catalog:read");
        client.DPoPJsonWebKey = dpopJwk; // Set the DPoP key from configuration
    });

builder.Services.AddClientCredentialsHttpClient(
    "catalog-api",
    ClientCredentialsClientName.Parse("catalog.client"),
    client => { client.BaseAddress = new Uri("https://api.example.com/catalog/"); });

var app = builder.Build();
app.Run();
```

## Key Points

- The DPoP JWK is loaded from `configuration["DPoP:JsonWebKey"]` — stored securely in Key Vault or user secrets, not generated at runtime.
- `DPoPJsonWebKey` is set on the client credentials client options.
- Generating ephemeral keys with `RSA.Create()` on every process restart would invalidate all previously issued DPoP-bound tokens, causing 401 errors until new tokens are obtained.
- For dynamic key resolution (e.g., from Azure Key Vault at runtime), implement `IDPoPKeyStore`.
