# Zero-Downtime Secret Rollover for `payment-gateway`

IdentityServer lets a client have more than one secret, and it will accept **any** of them at the token endpoint. That's the mechanism for rotating secrets without downtime: add the new one, keep the old one valid until every caller has switched, then remove the old one.

```csharp
using Duende.IdentityServer.Models;

new Client
{
    ClientId = "payment-gateway",
    AllowedGrantTypes = GrantTypes.ClientCredentials,

    // Multiple secrets — both accepted during the transition
    ClientSecrets =
    {
        new Secret(configuration["PaymentGateway:OldSecret"]!.Sha256()), // existing
        new Secret(configuration["PaymentGateway:NewSecret"]!.Sha256())  // new
    },

    AllowedScopes = { "payments" }
}
```

## Rollover process

1. **Add the new secret** alongside the current one and deploy. The client now authenticates with either secret, so nothing breaks.
2. **Roll the new secret out** to all copies of the client application. Since both work, you can do this gradually.
3. **Confirm** no one is still using the old secret.
4. **Remove the old secret** and redeploy so only the new one is valid.

## Notes

- IdentityServer checks the presented secret against every entry in `ClientSecrets`, so the old and new secrets both work during the overlap window.
- Once all clients have migrated, drop the old secret so it can no longer be used.
- Optionally set an `Expiration` on the old secret so it auto-disables after the migration window. Keep secrets in configuration or a vault, not hardcoded.
