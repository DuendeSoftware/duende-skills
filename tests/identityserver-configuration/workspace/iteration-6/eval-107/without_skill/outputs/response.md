```csharp
new Client
{
    ClientId = "payment-gateway",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    AllowedScopes = { "payments" },
    ClientSecrets =
    {
        new Secret("old-secret".Sha256())
        {
            Description = "Old", Expiration = new DateTime(2026, 12, 1, 0, 0, 0, DateTimeKind.Utc)
        },
        new Secret("new-secret".Sha256()) { Description = "New" }
    }
}
```
Rollover: 1) add the new secret alongside the old one; 2) deploy the new secret to the client; 3) once all instances use it, remove the old one (or let `Expiration` pass). IdentityServer accepts any non-expired secret, so there's no downtime. Store the hashes in config/DB and set the old secret's expiration as the deadline. Plain-text secrets should come from a vault.
