# DPoP for client credentials with a persisted key

The key comes from configuration (`DPoP:JsonWebKey`), so it is stable across restarts.

```csharp
var builder = WebApplication.CreateBuilder(args);

// JWK is stable: from Key Vault / secrets via configuration
var jwk = builder.Configuration["DPoP:JsonWebKey"]
    ?? throw new InvalidOperationException("DPoP:JsonWebKey is not configured");

builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("invoice.client", client =>
    {
        client.TokenEndpoint = new Uri("https://sts.example.com/connect/token");
        client.ClientId = ClientId.Parse(builder.Configuration["IdentityServer:ClientId"]!);
        client.ClientSecret = ClientSecret.Parse(builder.Configuration["IdentityServer:ClientSecret"]!);
        client.Scope = Scope.Parse("invoice");

        client.DPoPJsonWebKey = jwk;   // ✅ stable key
    });

builder.Services.AddClientCredentialsHttpClient("invoices",
    ClientCredentialsClientName.Parse("invoice.client"),
    c => c.BaseAddress = new Uri("https://api.example.com/invoices/"));

var app = builder.Build();

app.MapGet("/call-api", async (IHttpClientFactory f, CancellationToken ct) =>
{
    var client = f.CreateClient("invoices");
    return Results.Ok(await client.GetStringAsync("", ct));
});

app.Run();
```

## What the library does
DPoP proofs are added to token endpoint requests and every API call made through the factory client, and DPoP nonce challenges are retried (via the resiliency handler included in `AddClientCredentialsHttpClient`).

## Don't regenerate the key
```csharp
// ❌ ephemeral – lost on restart; previously issued DPoP-bound tokens stop working → 401s
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
```
Generate once (RSA/PS256, ES… all supported), store it in a secure store, and load it as above:

```csharp
var rsaKey = new RsaSecurityKey(RSA.Create(2048));
var jwkKey = JsonWebKeyConverter.ConvertFromSecurityKey(rsaKey);
jwkKey.Alg = "PS256";
var json = JsonSerializer.Serialize(jwkKey);   // store this as DPoP:JsonWebKey
```

For runtime rotation or per-client keys from a vault, implement `IDPoPKeyStore` and register it as a singleton.

For user tokens (OIDC) you'd set `options.DPoPJsonWebKey = jwk` in `AddOpenIdConnectAccessTokenManagement`, which also adds `dpop_jkt` to the authorize request.
