# Signing keys when migrating from `AddDeveloperSigningCredential()` to Duende

`AddDeveloperSigningCredential()` was only ever intended for development — it generates a temporary RSA key (usually persisted to a local `tempkey.jwk` file) that is not suitable for production. Here's how to handle the transition without breaking clients and APIs that are currently validating tokens signed with your existing key.

## 1. Remove `AddDeveloperSigningCredential()`

```csharp
// Remove this
services.AddIdentityServer()
    .AddDeveloperSigningCredential();
```

## 2. Use Duende automatic key management (recommended)

Duende IdentityServer includes **automatic key management** (Business/Enterprise editions). It creates, stores, announces, and rotates signing keys for you — no explicit signing-credential call is needed. Keys are persisted (in the operational store `Keys` table when you use EF Core) and published in the discovery document / JWKS endpoint so clients and APIs can discover them.

```csharp
// Automatic key management is built in — nothing to configure for the common case
builder.Services.AddIdentityServer();
```

(For Community edition, or if you need a fixed key, use `.AddSigningCredential(new X509Certificate2("signing.pfx", "password"))` instead.)

## 3. Protect existing tokens in production — the key point

Your concern is correct: if the signing key changes, already-issued tokens and any cached JWKS on the client/API side could fail validation. Two paths:

**A. If you can restart all clients and APIs (or they refresh their key metadata):**
Let automatic key management create the new key. Because relying parties fetch the current signing keys from your discovery document (`/.well-known/openid-configuration` → `jwks_uri`), once they refresh their key set they will **automatically pick up the new key**. APIs using the ASP.NET Core JWT bearer handler refresh JWKS periodically and on restart, so a coordinated restart makes them trust the new key immediately.

**B. If you cannot restart everything at once (true zero-downtime transition):**
Keep the **old key available alongside** the new key management for a transitional period, so tokens signed with the old key still validate while new tokens are signed with the new key. Export the existing RSA key and register it as an additional signing/validation credential:

```csharp
builder.Services.AddIdentityServer()
    .AddSigningCredential(existingRsaKey);   // old key kept for validation during transition
    // automatic key management issues/rotates the new keys in parallel
```

Once all clients and APIs have refreshed and you're confident nothing relies on the old key, remove it and let automatic key management take over fully.

## Summary

- **Remove** `AddDeveloperSigningCredential()`.
- **Prefer** Duende automatic key management as the replacement.
- If a clean restart of all relying parties is possible, they'll fetch the new key from the discovery document automatically.
- If not, **keep the old key temporarily** as an additional validation key so existing tokens keep working, then retire it after the transition.
