# `billing-service` Machine-to-Machine Client

Here are the API scopes and the client-credentials client, with the secret pulled from configuration.

### API Scopes

```csharp
using Duende.IdentityServer.Models;

public static IEnumerable<ApiScope> ApiScopes =>
    new ApiScope[]
    {
        new ApiScope("invoices.read", "Read invoices"),
        new ApiScope("invoices.pay",  "Pay invoices")
    };
```

### Client

```csharp
public static IEnumerable<Client> GetClients(IConfiguration configuration) =>
    new Client[]
    {
        new Client
        {
            ClientId = "billing-service",
            AllowedGrantTypes = GrantTypes.ClientCredentials,

            // Load the secret from configuration instead of hardcoding it
            ClientSecrets =
            {
                new Secret(configuration["Billing:ClientSecret"]!.Sha256())
            },

            AllowedScopes = { "invoices.read", "invoices.pay" }
        }
    };
```

### Registration and config

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(ApiScopes)
    .AddInMemoryClients(GetClients(builder.Configuration));
```

```json
{
  "Billing": {
    "ClientSecret": "your-secret-here"
  }
}
```

## Notes

- Uses `GrantTypes.ClientCredentials`, appropriate for a backend service with no user.
- `AllowedScopes` includes both `invoices.read` and `invoices.pay`.
- The secret is read from `configuration["Billing:ClientSecret"]` (appsettings, environment variables, user-secrets, or a vault) and hashed with `.Sha256()`. Keep the real value out of source control — use user-secrets in development and a secret manager in production.
