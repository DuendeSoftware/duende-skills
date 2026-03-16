# Secret Rotation for payment-gateway Client

To support zero-downtime secret rotation, you can configure multiple secrets for a client.

## Client with Multiple Secrets

```csharp
new Client
{
    ClientId = "payment-gateway",
    ClientName = "Payment Gateway",

    AllowedGrantTypes = GrantTypes.ClientCredentials,

    ClientSecrets =
    {
        new Secret("old-secret-value".Sha256()),   // Existing secret
        new Secret("new-secret-value".Sha256())    // New secret being rolled out
    },

    AllowedScopes = { "payments.process", "payments.read" }
}
```

## Rollover Process

1. **Add new secret**: Deploy the server with both old and new secrets configured. IdentityServer will accept either secret since it checks all secrets in the collection.

2. **Update clients**: Gradually update all client instances to use the new secret. During this period, both secrets work.

3. **Remove old secret**: Once all clients are using the new secret, remove the old one from the configuration and redeploy.

## How It Works

IdentityServer tries to validate the incoming credential against each secret in the collection. If any one matches, authentication succeeds. This means both secrets are valid simultaneously during the transition period.

After all clients have migrated to the new secret, you should remove the old secret to minimize risk.
