Rotate immediately rather than waiting for the schedule, and treat the old key as untrusted: **don't keep it as a validation key** (unlike routine rotation).

### Steps (automatic key management, 4 instances)

1. **Identify the compromised key** (`kid`) in the key store (`SigningKeys` table, or `KeyPath` files) and note the others.
2. **Create a new key and make it active.** With automatic management, deleting the compromised key causes a new key to be created. For zero gaps, ensure a new key exists first; the manager creates it with the usual initialization synchronization (`InitializationDuration`) across instances.
3. **Delete the compromised key from the store.** Don't just let it retire: retired keys remain published in discovery for `RetentionDuration`, and a leaked key must not stay trusted.
4. **Restart all 4 instances.** Keys are cached for `KeyManagement.KeyCacheDuration` (default 24h), so each instance must reload. Restart them (rolling is fine), then **verify each instance's JWKS (`/.well-known/openid-configuration/jwks`) no longer lists the compromised `kid`**, hitting every instance directly.
5. **Accept token invalidation.** Tokens signed with the key become invalid; users may need to sign in again. Because there's no overlap, clients/APIs with cached JWKS will refetch on unknown `kid`; expect some failures until their caches refresh.
6. **Revoke refresh tokens/persisted grants** issued before removal (all active grants if the exposure window is unknown).
7. **Notify relying parties**: clients and APIs caching JWKS, and SAML SPs with static IdP certificates.
8. **Investigate the exposure**: review how the key leaked, and how key store and Data Protection key storage are secured. If the DP keys/certificate may be exposed too, rotate them.
9. **Backups**: treat backups of signing keys as compromised. They're encrypted with Data Protection, so they only work with matching DP keys and the same `SetApplicationName`; make sure no backup still holds the leaked key, and back up/restore both together going forward.

### Multi-instance config to verify

```csharp
builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.Enabled = true;
        options.KeyManagement.RotationInterval = TimeSpan.FromDays(30);
    })
    .AddOperationalStore(o => o.ConfigureDbContext = b => b.UseSqlServer(connectionString));

builder.Services.AddDataProtection()
    .PersistKeysToDbContext<MyDbContext>()
    .ProtectKeysWithCertificate(certificate)
    .SetApplicationName("My.IdentityServer");
```

Shared key store + shared DP keys + fixed app name are what make all 4 instances pick up the same new key; otherwise you'll see `The key {ID} was not found in the key ring`.

If you use static keys instead: replace the `AddSigningCredential` key, remove it from any `AddValidationKey`, redeploy all instances.
