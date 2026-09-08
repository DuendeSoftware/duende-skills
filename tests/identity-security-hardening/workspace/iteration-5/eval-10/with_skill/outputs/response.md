# Rotating Static (Manually Managed) Signing Keys Safely

The golden rule of signing-key rotation is **overlap**: a key's *public* half must be visible to token consumers both **before** it starts signing and **after** it stops. Breaking either side of that overlap causes token validation failures. With static keys you must orchestrate this overlap yourself across multiple deployments — never swap keys in a single hard cut-over.

## The overlap requirement (why phased rotation is mandatory)

Downstream APIs validate tokens by fetching your **JWKS** (`/.well-known/openid-configuration/jwks`) and caching it. Two invariants follow:

1. **Publish before signing** — A new public key must already be available in JWKS (as a *validation* key) **before** IdentityServer uses its private half to sign any token. Otherwise an API receives a token whose `kid` it can't find, its cached JWKS is stale, and validation fails until the cache refreshes.
2. **Retain until expiry** — The retired public key must **remain available in JWKS until every token signed with it has expired**. If you drop it too early, in-flight tokens signed by the old key can no longer be validated.

## Phased rotation sequence

Use `AddSigningCredential` (the active signing key) together with `AddValidationKey` (extra public keys published in JWKS but not used to sign). Deploy each phase and wait for the appropriate propagation/expiry window between them.

```csharp
// Phase 1 — ANNOUNCE: keep signing with the OLD key, publish the NEW public key.
// Deploy, then wait >= JWKS cache TTL (e.g. >= 24h) so all consumers have fetched newKey.
idsvrBuilder.AddSigningCredential(oldKey, SecurityAlgorithms.RsaSha256);
idsvrBuilder.AddValidationKey(newKey, SecurityAlgorithms.RsaSha256);

// Phase 2 — SWITCH: sign with the NEW key, keep the OLD public key for validation.
// Deploy, then wait >= max access-token lifetime (e.g. >= 1h) so all old-key tokens expire.
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);

// Phase 3 — RETIRE: all tokens signed by the old key have expired; drop it.
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);
```

- **Between Phase 1 and Phase 2** you must wait at least the JWKS cache lifetime so consumers have the new key *before* it signs (invariant 1).
- **Between Phase 2 and Phase 3** you must wait at least the longest token lifetime so all old-key tokens have expired *before* you remove the old key (invariant 2).

## Prefer Automatic Key Management

**Automatic Key Management handles this entire overlap automatically** — it announces new keys during a `PropagationTime` window before they sign, and keeps retired keys for a `RetentionDuration` after, so JWKS always contains exactly the keys consumers need. **Only manual key managers must run the phased process above by hand.** If you can move off static keys, do — it removes the most error-prone part of key rotation:

```csharp
options.KeyManagement.RotationInterval  = TimeSpan.FromDays(90);
options.KeyManagement.PropagationTime   = TimeSpan.FromDays(14); // publish-before-sign overlap
options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14); // retain-after-retire overlap
```

## Summary

- Never hard-swap keys. Publish the new public key first, switch signing, then retire the old key — each as a separate deploy.
- Respect two waits: JWKS cache TTL before signing with the new key; max token lifetime before dropping the old key.
- `AddSigningCredential` = the key that signs; `AddValidationKey` = extra public keys in JWKS for validation only.
- Automatic Key Management does all of this for you; manual/static keys require the phased sequence.
