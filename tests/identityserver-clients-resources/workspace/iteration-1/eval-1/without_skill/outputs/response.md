# Configuring a Machine-to-Machine Client in IdentityServer

Here's how to set up the `billing-service` client for machine-to-machine communication with access to invoice-related scopes.

## API Scope Definitions

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("invoices.read", "Read invoices"),
    new ApiScope("invoices.pay", "Pay invoices")
];
```

## Client Definition

For a backend service that needs to call APIs without user interaction, use the client credentials grant type:

```csharp
new Client
{
    ClientId = "billing-service",
    ClientName = "Billing Service",

    AllowedGrantTypes = GrantTypes.ClientCredentials,

    ClientSecrets = { new Secret("my-secret-value".Sha256()) },

    AllowedScopes = { "invoices.read", "invoices.pay" }
}
```

## Registration in Program.cs

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);
```

## Notes

- The client credentials flow is designed for server-to-server communication where no user is involved.
- The secret should be kept secure. Consider using environment variables or a secrets manager for production deployments.
- PKCE is not applicable to the client credentials flow since there's no browser redirect involved.
