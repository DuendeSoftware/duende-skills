## Signing keys when migrating

`AddDeveloperSigningCredential()` still exists in Duende but is for development only. Remove it for production — but carefully, because clients and APIs already validate tokens signed with the current key.

### Decision
1. **Can you restart all clients and APIs?** Remove the old key and use **automatic key management** (Business/Enterprise editions). Clients fetch the new key from the discovery/JWKS document.
2. **Cannot restart everything?** Export the old signing key and configure it alongside automatic key management so existing tokens remain valid during the transition:
```csharp
builder.Services.AddIdentityServer()
    .AddSigningCredential(existingRsaKey)   // old key kept for validation
    // automatic key management handles new token signing
```
3. **Community edition** (no automatic key management): configure a static credential:
```csharp
builder.Services.AddIdentityServer()
    .AddSigningCredential(new X509Certificate2("signing.pfx", "password"));
```
(Load the cert from a secure store, not a literal password.)

### Practical steps
- Record the current signing key ID (the Migration Analysis Tool reports it) and check the JWKS in the old `/.well-known/openid-configuration/jwks`.
- Dev credentials are persisted in `tempkey.jwk` — that's where to extract the old key from.
- Keep the old key published until tokens signed with it have expired.
- Preserve the issuer URI as well (`options.IssuerUri`), since issuer changes also break trust.
- All instances must share keys; also set up Data Protection with an explicit app name and persistent store.
- Verify the discovery document and a full token flow after switching.
