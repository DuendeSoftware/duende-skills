# Machine-to-Machine Client: billing-service

Here's how to configure the `billing-service` M2M client with two API scopes, loading the secret from configuration rather than hardcoding it.

## 1. Define the API Scopes

First, define the two API scopes that the billing service needs access to:

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API"),
    new ApiScope("invoices.read", "Read invoices"),
    new ApiScope("invoices.pay", "Pay invoices")
];
```

## 2. Define the Client

The `billing-service` is a server-to-server (M2M) client with no interactive user, so it uses `GrantTypes.ClientCredentials`. The secret is loaded from `IConfiguration` rather than hardcoded:

```csharp
public static IEnumerable<Client> GetClients(IConfiguration configuration) =>
[
    new Client
    {
        ClientId = "billing-service",
        ClientName = "Billing Service",

        AllowedGrantTypes = GrantTypes.ClientCredentials,

        // Load secret hash from configuration — NOT hardcoded
        ClientSecrets = { new Secret(configuration["BillingService:ClientSecretHash"]) },

        AllowedScopes = { "invoices.read", "invoices.pay" }
    }
];
```

## 3. Store the Secret Hash in appsettings.json (or a vault)

In `appsettings.json`, store the SHA256 hash of the secret (Base64-encoded):

```json
{
  "BillingService": {
    "ClientSecretHash": "K7gNU3sdo+OL0wNhqoVWhr3g6s1xYv72ol/pe/Unols="
  }
}
```

In production, use a secrets manager (Azure Key Vault, AWS Secrets Manager, etc.) instead of `appsettings.json`.

## 4. Register in Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.GetClients(builder.Configuration))
    .AddTestUsers(TestUsers.Users);
```

## Key Points

- **`GrantTypes.ClientCredentials`** is the correct grant type for M2M/service-to-service communication — no interactive user is involved.
- **`RequireClientSecret`** defaults to `true`, which is correct for confidential M2M clients.
- **Never hardcode secrets** — loading from configuration or a vault avoids committing secrets to source control. The `new Secret("value".Sha256())` pattern is only for demos/prototyping.
- Both `invoices.read` and `invoices.pay` are defined as `ApiScope` instances and referenced in the client's `AllowedScopes`.
