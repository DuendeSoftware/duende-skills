# Zero-Downtime Secret Rollover for `payment-gateway`

IdentityServer validates a presented client secret against **every** secret in the client's `ClientSecrets` collection. So you add the new secret alongside the old one — both remain valid — let clients migrate, then remove the old secret.

```csharp
using Duende.IdentityServer.Models;

new Client
{
    ClientId = "payment-gateway",
    ClientName = "Payment Gateway",

    AllowedGrantTypes = GrantTypes.ClientCredentials,

    // Both secrets are valid simultaneously during the transition window
    ClientSecrets =
    {
        // Old (existing) secret — keep during rollover
        new Secret(configuration["PaymentGateway:OldSecret"]!.Sha256(), "old secret")
        {
            Expiration = new DateTime(2025, 12, 31) // optional: auto-expire the old one
        },

        // New secret — deploy to clients, then cut over
        new Secret(configuration["PaymentGateway:NewSecret"]!.Sha256(), "new secret")
    },

    AllowedScopes = { "payments" }
}
```

## Rollover Process

1. **Add the new secret** next to the existing one (as above) and deploy IdentityServer. Now the client accepts *either* secret — no downtime, nothing breaks for callers still using the old secret.
2. **Migrate the callers.** Update each instance of the `payment-gateway` client application to use the new secret. Because both are valid, you can roll this out gradually.
3. **Verify** that no traffic is authenticating with the old secret anymore (check logs / success events by secret description or introspection).
4. **Remove the old secret** from `ClientSecrets` and redeploy. Only the new secret remains valid.

## Notes

- **IdentityServer validates against all configured secrets** — the presented secret only has to match one entry in `ClientSecrets`, which is exactly what makes overlapping secrets work.
- Giving each `Secret` a **description** (the second constructor argument) makes the two easy to tell apart in logs and administration.
- Setting an **`Expiration`** on the old secret is a nice safety net — it will stop being accepted automatically after the transition date even if you forget to remove it.
- **Remove the old secret once migration completes** so a leaked/legacy credential can no longer be used. Keep secrets loaded from configuration/vault rather than hardcoded.
