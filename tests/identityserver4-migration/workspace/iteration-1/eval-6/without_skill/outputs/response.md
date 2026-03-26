# Signing Key Migration from IdentityServer4

## Remove AddDeveloperSigningCredential

You should **remove `AddDeveloperSigningCredential()`** as it's only meant for development:

```csharp
// Remove this
services.AddIdentityServer()
    .AddDeveloperSigningCredential()  // Remove
```

## Replacement Options

### Automatic Key Management
Duende IdentityServer includes automatic key management that handles signing keys for you:

```csharp
builder.Services.AddIdentityServer()
    .AddConfigurationStore(...)
    .AddOperationalStore(...);
// No explicit signing key configuration needed
```

### Static Signing Credential
Alternatively, configure a certificate:

```csharp
builder.Services.AddIdentityServer()
    .AddSigningCredential(new X509Certificate2("signing.pfx", "password"));
```

## Transition Concerns

Since your production clients validate tokens with the current key:
- The new key will be published in the JWKS endpoint
- Clients that check the discovery document will pick up the new key
- There may be a brief period where existing tokens can't be validated

Consider a phased rollout to minimize disruption.
