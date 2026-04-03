# Rotating Client Secrets Without Downtime

To rotate secrets for your `payment-gateway` client without downtime, you can add both the old and new secret to the client configuration. The server will try each configured secret when validating the client's credentials.

## Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("payments.process"),
        new ApiScope("payments.refund")
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "payment-gateway",
            AllowedGrantTypes = GrantTypes.ClientCredentials,

            // Both old and new secrets configured
            ClientSecrets =
            {
                new Secret("current-secret".Sha256()),  // existing secret
                new Secret("new-secret".Sha256())        // new secret being rolled in
            },

            AllowedScopes = { "payments.process", "payments.refund" }
        }
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

## Rollover Process

1. **Add the new secret**: Deploy the configuration with both secrets active. Both will be accepted for authentication.

2. **Update clients**: Gradually update all instances of the payment gateway service to use the new secret. Because both are valid, no service will be disrupted.

3. **Remove the old secret**: Once all clients have been updated, remove the old secret from the configuration.

This works because IdentityServer iterates through all secrets in the `ClientSecrets` list when validating. If any secret matches, the client is authenticated.

In production, you should avoid hardcoding secrets in source code. Store them in a configuration file or secret manager and load them at runtime.
