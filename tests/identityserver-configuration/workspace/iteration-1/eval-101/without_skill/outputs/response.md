# Billing Service Client Configuration

```csharp
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
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("billing-secret-2024".Sha256()) },
            AllowedScopes = { "invoices.read", "invoices.pay" }
        }
    });
```

This sets up a client credentials client with access to both invoice scopes. The client authenticates with a shared secret.
