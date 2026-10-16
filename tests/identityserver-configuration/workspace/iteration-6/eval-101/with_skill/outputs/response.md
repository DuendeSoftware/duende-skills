Client + scopes, with the secret hash loaded from configuration:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var secretHash = builder.Configuration["Clients:BillingService:SecretHash"]
    ?? throw new InvalidOperationException("Clients:BillingService:SecretHash is missing");

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("invoices.read", "Read invoices"),
        new ApiScope("invoices.pay", "Pay invoices")
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "billing-service",
            ClientName = "Billing Service",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret(secretHash) },   // pre-hashed value, never plaintext in source
            AllowedScopes = { "invoices.read", "invoices.pay" }
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

`appsettings.json` placeholder (don't commit real values; use user-secrets, env var `Clients__BillingService__SecretHash`, or a vault in production):
```json
{
  "Clients": { "BillingService": { "SecretHash": "" } }
}
```
Generate the value with `Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(plainSecret)))` (what `.Sha256()` does); give the plain secret to the billing service. Don't call `new Secret("literal".Sha256())` in source control.

Notes: M2M uses `ClientCredentials` with `RequireClientSecret = true` (default). Grant only the two scopes needed (least privilege). Since you only have scopes here, tokens carry no `aud`; add an `ApiResource` if the API needs audience validation. For stronger production security consider `private_key_jwt` or mTLS instead of a shared secret.
