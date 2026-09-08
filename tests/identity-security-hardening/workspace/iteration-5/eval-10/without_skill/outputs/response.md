# Rotating Static Signing Keys Without Breaking Validation

The key thing with signing-key rotation is that consumers of your tokens (your APIs) validate signatures using the public keys they fetch from your JWKS endpoint, and they cache that document. So you can't just replace the key in one step — you need an overlap period where both keys are available.

## The overlap requirement

1. **Publish the new key before you sign with it.** Add the new key as a validation key first so it shows up in the JWKS document. APIs cache the JWKS, so if you start signing with a key they haven't fetched yet, they'll reject those tokens (unknown `kid`) until their cache refreshes. Give them time to pick up the new key.
2. **Keep the old key until its tokens are gone.** After you switch signing to the new key, the old public key must stay in the JWKS until every token that was signed with it has expired. If you remove it too soon, valid but not-yet-expired tokens can't be verified anymore.

## Rotation sequence

In Duende IdentityServer you can use `AddSigningCredential` for the active signing key and `AddValidationKey` to publish additional public keys for validation only.

```csharp
// Step 1: Publish the new key as a validation key, keep signing with the old key.
idsvrBuilder.AddSigningCredential(oldKey);
idsvrBuilder.AddValidationKey(newKey);
// Deploy and wait long enough for all clients/APIs to refresh their cached JWKS.

// Step 2: Switch signing to the new key, keep the old key as a validation key.
idsvrBuilder.AddSigningCredential(newKey);
idsvrBuilder.AddValidationKey(oldKey);
// Deploy and wait until all tokens signed with the old key have expired.

// Step 3: Remove the old key entirely.
idsvrBuilder.AddSigningCredential(newKey);
```

The two waiting periods are important:
- Between step 1 and step 2, wait at least as long as your JWKS cache lifetime so everyone has the new key before it starts signing.
- Between step 2 and step 3, wait at least the maximum token lifetime so no valid token still depends on the old key.

## Summary

- Do it in phases, not a single swap.
- New public key must be published (visible in JWKS) before it's used to sign.
- Old public key must remain until all tokens it signed have expired.
- Use `AddValidationKey` to keep a key available for verification without using it to sign.

This phased approach keeps token validation working throughout the rotation.
