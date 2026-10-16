`AddDeveloperSigningCredential` creates a temporary key persisted to `tempkey.jwk` — not for production. Since clients/APIs validate with the current key:

1. **Don't just drop it**: a new key means tokens signed with the old key fail validation (and APIs cache JWKS).
2. **Extract the existing key** (from `tempkey.jwk` in the content root) and load it as a validation key so it remains published in JWKS while old tokens expire:
```csharp
.AddSigningCredential(newCert, SecurityAlgorithms.RsaSha256)
.AddValidationKey(oldKey)
```
3. **Use Duende automatic key management** (default in v6+, in Enterprise/Business editions): keys are rotated and stored in the operational store; you can disable it with `options.KeyManagement.Enabled = false` if you manage keys manually. In a staged approach: keep the old key as signing key until migration is stable, then move to the new key with the old as validation key until max token lifetime passes.
4. Store the new key in a certificate store / Key Vault, not in the repo.
5. In load-balanced environments all instances need the same keys.
6. Remove `tempkey.jwk` from deployment once done, and confirm the JWKS endpoint shows both keys.
