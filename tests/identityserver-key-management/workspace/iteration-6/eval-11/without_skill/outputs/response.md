**Response plan (4 instances sharing keys through EF operational store + shared Data Protection):**

1. **Contain**: determine which key leaked (`kid`). Take stock of the `SigningKeys` table (`Id`, `Created`, `Algorithm`).
2. **Rotate immediately**: automatic key management can't be told to rotate on demand, so create a new key: delete the compromised key's row from `SigningKeys` (or, if it's the active key, force new key creation). Keep other instances in mind—each caches keys (`KeyCacheDuration`, default 24h).
3. **Clear caches**: restart all 4 instances (or wait for cache expiry) so they reload keys from the store and discovery stops publishing the leaked key.
4. **Why delete, not retire**: the normal rotation flow keeps the old key in JWKS for validation; with a leak you must remove it so forged tokens fail validation. That invalidates all tokens signed with it — users must re-authenticate and clients re-fetch JWKS.
5. **Rotate data protection** if the DP ring/cert may also be exposed, and secrets for clients.
6. **Investigate** logs for tokens with the leaked `kid` issued by someone else; consider revoking refresh tokens (persisted grants) for affected users.
7. **Prevent**: encrypt DP keys at rest, restrict DB access, shorten `RotationInterval`.

Config sanity (same on all 4):

```csharp
builder.Services.AddIdentityServer(o => {
    o.KeyManagement.Enabled = true;
    o.KeyManagement.RotationInterval = TimeSpan.FromDays(30);
}).AddOperationalStore(/* shared SQL */);
builder.Services.AddDataProtection().SetApplicationName("IdentityServer").PersistKeysToDbContext<DpContext>();
```

Then, after deletion, the first instance to need a key creates a new one; the others pick it up from the DB (with initial synchronization delay).
