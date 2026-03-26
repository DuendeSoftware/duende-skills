# Migrating Signing Keys: AddDeveloperSigningCredential → Duende Key Management

## Remove AddDeveloperSigningCredential

The first step is to **remove `AddDeveloperSigningCredential()`** from your configuration. This method creates a temporary RSA key stored in a `tempkey.jwk` file — it was never intended for production use and is not how Duende IdentityServer manages keys.

```csharp
// Remove this:
services.AddIdentityServer()
    .AddDeveloperSigningCredential()  // DELETE THIS LINE
    .AddConfigurationStore(...)
    .AddOperationalStore(...);
```

## Replacement: Automatic Key Management

Duende IdentityServer (Business and Enterprise editions) includes **automatic key management** that handles signing key creation, rotation, and retirement without any explicit configuration:

```csharp
// New: No signing credential call needed
builder.Services.AddIdentityServer()
    .AddConfigurationStore(...)
    .AddOperationalStore(...);
// Automatic key management is built-in — keys are stored in the Keys table
```

Keys are automatically:
- Created when needed
- Rotated on a configurable schedule (default: 90 days)
- Announced in the discovery document before becoming active
- Retired after a grace period

The keys are persisted in the `Keys` table in the operational store database.

## Handling the Transition: Existing Tokens in Production

Since you have clients and APIs in production that are already validating tokens signed with the current developer signing key, you need to plan the transition carefully:

### Option 1: If You Can Restart All Clients and APIs

If you can coordinate a restart of all client applications and APIs, the transition is simple:

1. Remove `AddDeveloperSigningCredential()`
2. Deploy Duende IdentityServer — automatic key management will create a new signing key
3. Restart all clients and APIs — they will fetch the new signing key from the discovery document (`/.well-known/openid-configuration/jwks`) automatically
4. Existing access tokens signed with the old key will fail validation, but new tokens will work immediately

This approach is cleanest but requires a brief window where in-flight tokens are invalid.

### Option 2: Transitional Period (Cannot Restart Everything)

If you cannot restart all clients/APIs simultaneously, keep the old key available alongside automatic key management:

```csharp
// Export the developer signing key from tempkey.jwk first
var existingKey = LoadExistingRsaKeyFromTempKeyJwk();

builder.Services.AddIdentityServer()
    .AddSigningCredential(existingKey)  // old key still used for validation
    // automatic key management creates new keys for signing
    .AddConfigurationStore(...)
    .AddOperationalStore(...);
```

During the transition period:
- New tokens are signed with the new automatically-managed key
- The old key remains in the JWKS endpoint for validation of existing tokens
- Once all old tokens have expired (check your access token lifetime, typically 1 hour), remove the old key

### For Community Edition

If using the Community edition (which does not include automatic key management), configure a static signing credential:

```csharp
builder.Services.AddIdentityServer()
    .AddSigningCredential(new X509Certificate2("signing.pfx", "password"));
```

## Key Takeaway

The developer signing key was always temporary. Duende's automatic key management is the proper production solution — it handles rotation, announcement, and retirement automatically. Plan your cutover based on whether you can restart dependent services.
