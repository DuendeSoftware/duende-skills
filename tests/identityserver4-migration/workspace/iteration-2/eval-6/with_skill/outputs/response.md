# Signing Key Migration: AddDeveloperSigningCredential → Duende Automatic Key Management

## Remove AddDeveloperSigningCredential

Your current `Startup.cs` uses `AddDeveloperSigningCredential()`, which is a development-only signing key. Remove it:

```csharp
// Old (remove this)
services.AddIdentityServer()
    .AddDeveloperSigningCredential();

// New: Duende IdentityServer (Business/Enterprise) includes automatic key management
// No explicit call needed — keys are created and rotated automatically
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
});
```

## Automatic Key Management (Recommended)

Duende IdentityServer's automatic key management (available in Business and Enterprise editions):
- Creates signing keys automatically
- Rotates keys based on configurable intervals
- Stores keys in the operational database (`Keys` table)
- Publishes both current and previous keys in the discovery document for validation

## Handling Existing Tokens in Production

Since you have clients and APIs already validating tokens signed with the current developer signing key, you need to plan a transition:

### Option 1: All clients/APIs can be restarted

If all clients and APIs can be restarted, they will pick up the new signing key from the discovery document (`/.well-known/openid-configuration/jwks`) automatically. No special transition is needed — just remove `AddDeveloperSigningCredential()` and let automatic key management take over.

### Option 2: Cannot restart everything simultaneously

Keep the old signing key available temporarily alongside automatic key management so existing tokens remain valid during the transition period:

```csharp
// Transitional: keep old key for validation while automatic key management handles new signing
builder.Services.AddIdentityServer()
    .AddSigningCredential(existingRsaKey)  // old key stays for validation
    // automatic key management creates new keys for signing
```

Once all outstanding tokens signed with the old key have expired (or all clients/APIs have been restarted to fetch the new JWKS), you can remove the `AddSigningCredential` call.

## For Community Edition

If using the Community edition (which does not include automatic key management), configure a static signing credential:

```csharp
builder.Services.AddIdentityServer()
    .AddSigningCredential(new X509Certificate2("signing.pfx", "password"));
```
