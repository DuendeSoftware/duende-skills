# Migrating from AddDeveloperSigningCredential to Duende Key Management

Looking at your `Startup.cs`, you're currently using `AddDeveloperSigningCredential()` — this must be **removed** when migrating to Duende IdentityServer. It was only intended for development in IdentityServer4 and should never have been used in production.

## Recommended Replacement: Automatic Key Management

Duende IdentityServer (Business and Enterprise editions) includes **automatic key management** as a built-in feature. This is the recommended replacement — no explicit call is needed. Keys are created, rotated, and retired automatically:

```csharp
// Old (remove this)
services.AddIdentityServer()
    .AddDeveloperSigningCredential();

// New: Automatic key management is built-in (Business/Enterprise)
// No explicit signing credential call needed
builder.Services.AddIdentityServer()
    .AddConfigurationStore(options => { /* ... */ })
    .AddOperationalStore(options => { /* ... */ });
```

For the Community edition, configure a static signing credential instead:

```csharp
builder.Services.AddIdentityServer()
    .AddSigningCredential(new X509Certificate2("signing.pfx", "password"));
```

## Handling Existing Tokens in Production

Since you have clients and APIs already validating tokens signed with the current key, you need a transition strategy:

### Option 1: If You Can Restart All Clients and APIs

If all clients and APIs can be restarted, they will **pick up the new key from the discovery document automatically**. The `/.well-known/openid-configuration/jwks` endpoint will serve the new key(s), and clients that fetch keys from discovery will start validating against them on next key refresh. Simply remove `AddDeveloperSigningCredential()` and let automatic key management take over.

### Option 2: If You Cannot Restart Everything

Keep the old signing key available alongside automatic key management during a **transitional period**. This ensures existing tokens signed with the old key remain valid while new tokens are signed with the new key:

```csharp
// Transitional: keep old key for validation while automatic key management creates new keys
builder.Services.AddIdentityServer()
    .AddValidationKey(existingRsaKey)  // old key remains available for validation
    // automatic key management handles new token signing
```

Once all old tokens have expired (based on your access token lifetime) and all clients have refreshed their discovery metadata, you can remove the old validation key.
