# Configuring DPoP for Client Credentials Token Management

DPoP (Demonstrating Proof-of-Possession) binds an access token to a key pair held by your client. To keep already-issued tokens valid across restarts, the key must be **persisted**, not generated fresh each time the process starts. Since you already have the JWK in configuration at `DPoP:JsonWebKey`, load it from there.

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// ✅ Load the persisted JWK from configuration instead of generating one at startup
var dpopJwk = builder.Configuration["DPoP:JsonWebKey"];
if (string.IsNullOrWhiteSpace(dpopJwk))
{
    throw new InvalidOperationException("Missing DPoP:JsonWebKey configuration.");
}

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog", client =>
    {
        client.TokenEndpoint = "https://sts.example.com/connect/token";
        client.ClientId = "catalog-worker";
        client.ClientSecret = "worker-secret";
        client.Scope = "catalog:read";

        // Attach the DPoP JSON Web Key so tokens are DPoP-bound
        client.DPoPJsonWebKey = dpopJwk;
    });

builder.Services.AddClientCredentialsHttpClient("catalog-client", "catalog", client =>
{
    client.BaseAddress = new Uri("https://api.example.com/catalog/");
});
```

With `DPoPJsonWebKey` set, the library will generate and send DPoP proof tokens on token requests and on outgoing API calls automatically.

## Don't regenerate the key on every restart

```csharp
// ❌ This creates a brand new key each time the app starts.
// Every DPoP-bound token issued against the old key immediately becomes invalid.
var key = new RsaSecurityKey(RSA.Create(2048));
```

Generate the JWK once during provisioning, store it in a secret store or configuration (as you have at `DPoP:JsonWebKey`), and load it at startup. If you need to rotate keys or resolve them per-client at runtime, check whether the library exposes a key-store abstraction you can implement instead of hard-coding the key.

## Practical notes

- Keep the JWK in a real secret store (Key Vault, user-secrets, environment variables) rather than committed configuration.
- If you also enable DPoP on interactive user flows, be aware the proof key is carried in the auth session, which increases cookie/state size.
