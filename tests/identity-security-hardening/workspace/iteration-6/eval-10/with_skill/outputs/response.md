# Rotating static signing keys

Static keys have no automatic overlap, so you must create it yourself. The rule:

> **Publish a new public key *before* you sign with it, and keep a retired public key available *until every token signed with it has expired*.** Consumers must be able to fetch the key from JWKS both before it starts signing and after it stops.

Never swap the key in a single deployment: APIs would see an unknown `kid`, or reject tokens signed by the old key that are still in flight.

## Three-phase rotation

**Phase 1 – Announce the new key, keep signing with the old one**
```csharp
idsvrBuilder.AddSigningCredential(oldKey, SecurityAlgorithms.RsaSha256);
idsvrBuilder.AddValidationKey(newKey, SecurityAlgorithms.RsaSha256);
```
Deploy to *all* nodes, then wait ≥ 24 h (at least the longest JWKS cache time of your APIs/clients) so every consumer has the new public key.

**Phase 2 – Switch signing to the new key, retain the old for validation**
```csharp
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);
```
Deploy and wait ≥ the longest token lifetime signed by the old key (default access token 1 h; also consider identity tokens, logout tokens, and any longer-lived JWTs) so that old tokens expire while their key remains published.

**Phase 3 – Drop the old key**
```csharp
idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);
```
All old tokens have expired, so removal is safe.

## The two overlap windows
1. **Before signing (propagation)**: new key published in JWKS ≥ cache refresh interval (≥ 24 h).
2. **After signing (retention)**: old key published ≥ the longest token lifetime.

Make sure every load-balanced node has the same configuration at each phase and store keys securely (never commit them).

## Recommendation
Prefer **Automatic Key Management** (`KeyManagement.Enabled = true`), which does this announce/activate/retire cycle for you via `RotationInterval` (90 days), `PropagationTime` (≥ 24 h, e.g. 14 days), and `RetentionDuration` (≥ token lifetime), with keys encrypted by Data Protection. Use ES256 or RS256 only (never HS256 for asymmetric signing).
