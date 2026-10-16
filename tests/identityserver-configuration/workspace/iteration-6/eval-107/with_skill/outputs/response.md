IdentityServer accepts **any** non-expired secret in `ClientSecrets`, so rollover is just a matter of holding two at once:

```csharp
new Client
{
    ClientId = "payment-gateway",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    AllowedScopes = { "payments" },

    ClientSecrets =
    {
        // primary / old secret, with an optional expiry as the end of the transition
        new Secret(configuration["Clients:PaymentGateway:OldSecretHash"])
        {
            Description = "Old secret (rotating out)",
            Expiration = new DateTime(2026, 12, 31, 0, 0, 0, DateTimeKind.Utc)
        },
        // secondary / new secret
        new Secret(configuration["Clients:PaymentGateway:NewSecretHash"])
        {
            Description = "New secret"
        }
    }
}
```
(Equivalently `client.ClientSecrets = new[] { primary, secondary };`.)

Rollover process:
1. **Add** the new secret next to the existing one and deploy IdentityServer. Both authenticate.
2. **Roll out** the new secret to the payment-gateway instances (vault/config), gradually; no downtime since both are valid.
3. **Verify** via logs/events that only the new secret is used.
4. **Remove** the old secret (or let its `Expiration` pass) and redeploy.

Best practices: store only hashes (loaded from configuration or vault, never plaintext in source); consider `private_key_jwt` with certificates, which allows the same overlap with two certificates/keys.
