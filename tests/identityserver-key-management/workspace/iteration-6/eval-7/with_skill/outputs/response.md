**What's wrong:** Automatic key management encrypts signing keys at rest with ASP.NET Core Data Protection (`DataProtectKeys = true`). The default Data Protection configuration uses machine-specific key storage. Each instance has its own DP key ring, so keys written by instance A can't be unprotected by instance B: `CryptographicException: The key {ID} was not found in the key ring`. (The shared `keys` directory/signing key store is fine; the DP ring is the issue.)

**Fix:** shared, durable Data Protection persistence, protected at rest, and an explicit application name identical on all instances:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<MyDbContext>()          // or PersistKeysToAzureBlobStorage, etc.
    .ProtectKeysWithCertificate(certificate)        // or ProtectKeysWithAzureKeyVault
    .SetApplicationName("My.IdentityServer");
```

Also:
- Share the signing key store between instances too: either keep `KeyManagement.KeyPath` on a shared volume, or preferably use the EF operational store:
  ```csharp
  builder.Services.AddIdentityServer()
      .AddOperationalStore(o => o.ConfigureDbContext = b => b.UseSqlServer(connectionString));
  ```
- A changed or unset application name breaks keys after redeploy, so always set it.
- Keys already encrypted with a DP ring that's no longer available can't be read; delete those signing keys (they'll be regenerated) after fixing configuration.
- Don't disable `DataProtectKeys` as a workaround; that would leave signing keys unencrypted.
- Make sure the `keys` directory isn't committed to source control (keys protected by dev-only DP keys fail in production).
