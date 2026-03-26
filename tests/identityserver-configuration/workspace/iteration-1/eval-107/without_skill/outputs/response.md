# Secret Rotation for payment-gateway

To support zero-downtime secret rotation, you can configure multiple secrets:

```csharp
new Client
{
    ClientId = "payment-gateway",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets =
    {
        new Secret("current-secret".Sha256()),
        new Secret("new-secret".Sha256())
    },
    AllowedScopes = { "payments.process", "payments.refund" }
}
```

IdentityServer will accept either secret, so you can gradually roll out the new secret to all service instances. Once all instances are using the new secret, remove the old one from the configuration.
