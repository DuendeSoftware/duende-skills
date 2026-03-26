# Machine-to-Machine Client: billing-service

Here's the complete configuration with the client definition, API scopes, and secret loaded from configuration:

```csharp
var builder = WebApplication.CreateBuilder(args);

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseSuccessEvents = true;
})
    .AddInMemoryApiScopes(new ApiScope[]
    {
        new ApiScope("invoices.read", "Read invoices"),
        new ApiScope("invoices.pay", "Process invoice payments")
    })
    .AddInMemoryClients(new Client[]
    {
        new Client
        {
            ClientId = "billing-service",
            ClientName = "Billing Service",

            AllowedGrantTypes = GrantTypes.ClientCredentials,

            // Load secret from configuration - NEVER hardcode in source
            ClientSecrets =
            {
                new Secret(builder.Configuration["Clients:BillingService:Secret"].Sha256())
            },

            AllowedScopes = { "invoices.read", "invoices.pay" }
        }
    });
```

Then in `appsettings.json` (or preferably user secrets / vault for production):

```json
{
  "Clients": {
    "BillingService": {
      "Secret": "generate-a-strong-random-secret-here"
    }
  }
}
```

## Key Design Decisions

### Grant Type: ClientCredentials

`GrantTypes.ClientCredentials` is the correct grant type for machine-to-machine communication. There's no interactive user - the billing service authenticates with its own credentials (client ID + secret) and receives an access token with the requested scopes.

### Secret from Configuration

The secret is loaded from `IConfiguration` via `builder.Configuration["Clients:BillingService:Secret"]` and then hashed with `.Sha256()`. This keeps the raw secret out of source code. In production, use Azure Key Vault, HashiCorp Vault, or environment variables instead of appsettings.json.

### RequireClientSecret

`RequireClientSecret` defaults to `true`, which is correct for M2M clients. The billing service is a confidential client that can securely store its credentials.
