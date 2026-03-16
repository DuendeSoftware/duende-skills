# Zero-Downtime Secret Rotation for payment-gateway Client

## Client Configuration with Multiple Secrets

IdentityServer validates against **all secrets** in the `ClientSecrets` collection. To perform zero-downtime rotation, add the new secret alongside the old one:

```csharp
new Client
{
    ClientId = "payment-gateway",
    ClientName = "Payment Gateway",

    AllowedGrantTypes = GrantTypes.ClientCredentials,

    // Both old and new secrets are valid simultaneously
    ClientSecrets =
    {
        new Secret(configuration["PaymentGateway:OldSecretHash"]),  // Old secret — still valid
        new Secret(configuration["PaymentGateway:NewSecretHash"])   // New secret — being rolled out
    },

    AllowedScopes = { "payments.process", "payments.read" }
}
```

## The Rollover Process

### Phase 1: Add New Secret
Add the new secret to the `ClientSecrets` collection alongside the existing one. Deploy IdentityServer with both secrets. **IdentityServer validates against all configured secrets**, so both the old and new secrets will work. Clients using the old secret continue to function without interruption.

### Phase 2: Migrate Clients
Update all instances of the payment-gateway service to use the new secret. This can be done gradually — some instances can use the old secret while others use the new one. Both remain valid during this period.

### Phase 3: Remove Old Secret
After all clients have migrated to the new secret and you've confirmed no traffic is using the old secret, remove it from the configuration:

```csharp
ClientSecrets =
{
    new Secret(configuration["PaymentGateway:NewSecretHash"])   // Only the new secret remains
}
```

**Remove the old secret after all clients have migrated** to prevent it from being used if compromised.

## Key Points

- IdentityServer validates against **all** secrets in the `ClientSecrets` collection — the first one that matches succeeds.
- This means you can have any number of active secrets at the same time.
- Secrets should be stored as hashes (loaded from configuration/vault), not as plain text in source code.
- Consider adding `Description` and `Expiration` properties to secrets for auditing:

```csharp
ClientSecrets =
{
    new Secret(configuration["PaymentGateway:OldSecretHash"])
    {
        Description = "Original secret - deprecating 2026-04-01",
        Expiration = new DateTime(2026, 4, 15)  // Auto-expire as safety net
    },
    new Secret(configuration["PaymentGateway:NewSecretHash"])
    {
        Description = "Rotated secret - active 2026-03-15"
    }
}
```
