# `billing-service` Machine-to-Machine Client

Below are the two API scope definitions and the client credentials client for `billing-service`, with the secret loaded from configuration rather than hardcoded.

### API Scopes

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<ApiScope> ApiScopes =>
        new ApiScope[]
        {
            new ApiScope("invoices.read", "Read invoices"),
            new ApiScope("invoices.pay",  "Pay invoices")
        };
}
```

### Client (secret from configuration)

```csharp
public static IEnumerable<Client> Clients(IConfiguration configuration) =>
    new Client[]
    {
        new Client
        {
            ClientId = "billing-service",
            ClientName = "Billing Service",

            AllowedGrantTypes = GrantTypes.ClientCredentials,
            // RequireClientSecret is true by default for confidential clients
            RequireClientSecret = true,

            // Secret hash loaded from configuration/secret store — never hardcoded
            ClientSecrets =
            {
                new Secret(configuration["BillingService:ClientSecret"]!.Sha256())
            },

            AllowedScopes = { "invoices.read", "invoices.pay" }
        }
    };
```

### Registration

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients(builder.Configuration));
```

### appsettings.json (store the SHA-256 hash, or the raw value via user-secrets/vault)

```json
{
  "BillingService": {
    "ClientSecret": "<the client secret value>"
  }
}
```

## Notes

- **`GrantTypes.ClientCredentials`** — correct for a payment-processing backend with no interactive user.
- **`AllowedScopes`** lists both `invoices.read` and `invoices.pay`, matching the two `ApiScope` definitions.
- **Secret from configuration** — `configuration["BillingService:ClientSecret"]` pulls the value from `appsettings.json`, environment variables, user-secrets, or a bound key vault, keeping it out of source control. For real deployments prefer user-secrets locally and a managed secret store (Azure Key Vault, AWS Secrets Manager, etc.) in production, or move to `private_key_jwt` to avoid a shared secret entirely.
- `.Sha256()` hashes the configured value because IdentityServer's default secret validator compares hashes. If you'd rather store the already-hashed value, drop `.Sha256()` and put the hash in configuration directly.
