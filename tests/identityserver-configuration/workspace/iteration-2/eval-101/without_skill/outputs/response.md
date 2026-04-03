Here's how to set up the billing service client:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("invoices.read"),
        new ApiScope("invoices.pay")
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "billing-service",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("billing-secret".Sha256()) },
            AllowedScopes = { "invoices.read", "invoices.pay" }
        }
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

This creates a machine-to-machine client that uses client credentials to access the invoice scopes.
