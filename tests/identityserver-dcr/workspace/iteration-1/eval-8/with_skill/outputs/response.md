# DCR Security Hardening Guide

Here are the most common security mistakes with DCR and how to avoid them:

## 1. Unauthenticated DCR Endpoint

**Mistake:** Exposing `/connect/dcr` without authentication or authorization.

```csharp
// WRONG - anyone can register clients
app.MapDynamicClientRegistration();

// CORRECT - require authorization
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr-policy");
```

Always secure the DCR endpoint with a JWT bearer authentication scheme and an authorization policy requiring a specific scope.

## 2. Unrestricted Grant Types

**Mistake:** Allowing dynamically registered clients to use any grant type.

A malicious registrant could create a client_credentials client and gain direct API access. Always restrict to `authorization_code` and enforce PKCE:

```csharp
protected override Task ValidateGrantTypesAsync(
    DynamicClientRegistrationContext context)
{
    if (context.Request.GrantTypes.Any(gt => gt != "authorization_code"))
    {
        context.SetError("Only authorization_code is allowed");
        return Task.CompletedTask;
    }
    return base.ValidateGrantTypesAsync(context);
}
```

## 3. In-Memory Stores in Production

**Mistake:** Using in-memory stores for dynamically registered clients.

- Clients are lost on restart
- No shared state across instances
- No audit trail

Use `AddClientConfigurationStore()` from the EF package for production.

## 4. Plaintext Secret Storage

**Mistake:** Storing client secrets in plaintext.

IdentityServer hashes secrets before passing them to `IClientConfigurationStore`. If you implement a custom store, ensure you store the hashed values as-is. Never reverse the hash or store the original plaintext secret.

## 5. Unvalidated Software Statements

**Mistake:** Accepting software statements without validating the signature or issuer.

Software statements are signed JWTs. You must validate them against trusted signing keys and reject unknown issuers:

```csharp
var result = await handler.ValidateTokenAsync(softwareStatement,
    new TokenValidationParameters
    {
        ValidIssuer = "https://trusted-authority.example.com",
        IssuerSigningKeys = trustedKeys,
        ValidateLifetime = true
    });
```

Never accept a software statement from an untrusted or unknown issuer.

## 6. Additional Hardening

- **Rate limit** the DCR endpoint to prevent abuse
- **Log all registrations** for audit trails
- **Restrict redirect URIs** to HTTPS
- **Set short token lifetimes** for dynamically registered clients
- **Validate redirect URI patterns** against an allowlist if possible
