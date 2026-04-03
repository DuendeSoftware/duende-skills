# Zero-Downtime Secret Rotation for Client Credentials Client

To support zero-downtime secret rotation for the `payment-gateway` client, you can configure multiple secrets in the `ClientSecrets` collection. IdentityServer validates incoming client credentials against all configured secrets, so both the old and new secrets will work simultaneously during the transition period.

## Configuration

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

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
        new ApiScope("payments.process", "Process payments"),
        new ApiScope("payments.refund", "Issue refunds")
    })
    .AddInMemoryClients(new Client[]
    {
        new Client
        {
            ClientId = "payment-gateway",
            ClientName = "Payment Gateway Service",

            AllowedGrantTypes = GrantTypes.ClientCredentials,

            // Both old and new secrets are valid during the rollover period
            ClientSecrets =
            {
                // Current (old) secret — will be removed after migration
                new Secret("old-secret-hash".Sha256())
                {
                    Description = "Original secret — remove after all services migrate"
                },

                // New secret — services should migrate to this
                new Secret("new-secret-hash".Sha256())
                {
                    Description = "New secret — deployed 2026-04-03"
                }
            },

            AllowedScopes = { "payments.process", "payments.refund" }
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.Run();
```

## Secret Rollover Process

The rollover process is straightforward because IdentityServer validates against **all** configured secrets in the `ClientSecrets` collection. Any matching secret will successfully authenticate the client.

### Step-by-Step

1. **Add the new secret** alongside the existing one in the `ClientSecrets` collection. Deploy this change to IdentityServer. At this point, both secrets are valid.

2. **Migrate client services** to use the new secret. Update each instance of the payment gateway service to send the new secret when authenticating. Since both secrets are valid, there is no downtime — services using the old secret continue to work.

3. **Verify all services are migrated**. Monitor your logs to confirm no clients are still authenticating with the old secret.

4. **Remove the old secret** from the `ClientSecrets` collection. Deploy this change. Now only the new secret is valid.

### Production Recommendations

- **Don't hardcode secrets in source code.** Load secret hashes from configuration or a vault:

  ```csharp
  ClientSecrets =
  {
      new Secret(configuration["PaymentGateway:CurrentSecretHash"]),
      new Secret(configuration["PaymentGateway:PreviousSecretHash"])
  }
  ```

- **Add descriptions and/or expiration dates** to secrets to track which is which:

  ```csharp
  new Secret("hash") { Description = "Rotated 2026-04-03", Expiration = new DateTime(2026, 07, 01) }
  ```

- **Use asymmetric credentials** (private_key_jwt or mTLS) for high-security payment systems. These eliminate shared secrets entirely and are easier to rotate because only the public key is registered with IdentityServer.
