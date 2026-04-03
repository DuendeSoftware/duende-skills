Here's the `billing-service` M2M client with API scope definitions. The secret is loaded from configuration rather than hardcoded.

**API Scope definitions:**

```csharp
var apiScopes = new List<ApiScope>
{
    new ApiScope("invoices.read", "Read invoices"),
    new ApiScope("invoices.pay", "Pay invoices")
};
```

**Client definition in Program.cs:**

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("invoices.read", "Read invoices"),
        new ApiScope("invoices.pay", "Pay invoices")
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "billing-service",
            ClientName = "Billing Service",

            AllowedGrantTypes = GrantTypes.ClientCredentials,

            // Load secret from configuration — never hardcode in source
            ClientSecrets = { new Secret(builder.Configuration["Clients:BillingService:Secret"].Sha256()) },

            AllowedScopes = { "invoices.read", "invoices.pay" }
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

**appsettings.json:**

```json
{
  "Clients": {
    "BillingService": {
      "Secret": "your-secret-value-here"
    }
  }
}
```

The secret is loaded from `IConfiguration` at `Clients:BillingService:Secret` and then hashed with `.Sha256()`. In production, store secrets in Azure Key Vault, AWS Secrets Manager, or another vault — not in `appsettings.json`. The configuration approach here is a step up from hardcoding but should be combined with a secrets provider for production.
