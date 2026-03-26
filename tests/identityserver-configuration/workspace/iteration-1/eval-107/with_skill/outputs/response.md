# Zero-Downtime Secret Rotation for payment-gateway

Here's how to configure the client with multiple secrets for zero-downtime rotation:

```csharp
new Client
{
    ClientId = "payment-gateway",
    ClientName = "Payment Gateway Service",

    AllowedGrantTypes = GrantTypes.ClientCredentials,

    ClientSecrets =
    {
        // Current active secret
        new Secret(builder.Configuration["Clients:PaymentGateway:CurrentSecret"].Sha256())
        {
            Description = "Current secret - deployed 2026-01-15"
        },

        // New secret being rolled out
        new Secret(builder.Configuration["Clients:PaymentGateway:NewSecret"].Sha256())
        {
            Description = "New secret - rolling out 2026-03-26"
        }
    },

    AllowedScopes = { "payments.process", "payments.refund" }
}
```

## Rollover Process

### How It Works

IdentityServer validates the incoming client secret against **all configured secrets** in the `ClientSecrets` collection. If any secret matches, authentication succeeds. This means both old and new secrets work simultaneously during the transition.

### Step-by-Step Rollover

1. **Add new secret**: Add the new secret to the `ClientSecrets` collection alongside the existing one. Deploy to IdentityServer. Both secrets now work.

2. **Update clients**: Gradually update all instances of the payment-gateway service to use the new secret. Since both secrets are valid, there's no downtime - instances using either secret authenticate successfully.

3. **Verify migration**: Monitor logs to confirm all payment-gateway instances are using the new secret. Check for authentication events to ensure no instances are still using the old secret.

4. **Remove old secret**: Once all instances have migrated, remove the old secret from the `ClientSecrets` collection:

```csharp
ClientSecrets =
{
    new Secret(builder.Configuration["Clients:PaymentGateway:NewSecret"].Sha256())
    {
        Description = "Active secret - deployed 2026-03-26"
    }
}
```

### Optional: Expiration Dates

You can set expiration dates on secrets to automatically invalidate them:

```csharp
new Secret(oldSecretHash)
{
    Expiration = new DateTime(2026, 4, 15) // Auto-expire after transition
}
```

### Best Practices

- Always load secrets from configuration or a vault, not from source code.
- Log which secret was used (by description/index) to track migration progress.
- Set calendar reminders for secret expiration dates.
- Document the rotation schedule and process.
