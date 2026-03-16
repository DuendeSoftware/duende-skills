# DCR Security Hardening Guide

Here are the common security mistakes and anti-patterns to avoid when implementing Dynamic Client Registration (DCR) in Duende IdentityServer.

## 1. Exposing the DCR Endpoint Without Authentication

**Anti-pattern**: Calling `MapDynamicClientRegistration()` without `RequireAuthorization()`.

An unauthenticated DCR endpoint allows anyone on the internet to register clients. This is the single most dangerous DCR misconfiguration.

**Fix**: Always secure the endpoint with an authorization policy:

```csharp
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");
```

Use JWT bearer authentication with a scope check so only authorized callers can register clients.

## 2. Allowing Unrestricted Grant Types

**Anti-pattern**: Accepting any `grant_types` value in DCR requests without validation.

If you allow dynamically registered clients to use any grant type (e.g., `client_credentials`, `implicit`), you open the door to:
- Clients that bypass user consent
- Clients that use insecure flows (implicit)
- Machine-to-machine clients that shouldn't exist

**Fix**: Override `ValidateGrantTypesAsync` in your `DynamicClientRegistrationValidator` to restrict allowed grant types, and enforce PKCE:

```csharp
protected override Task ValidateGrantTypesAsync(
    DynamicClientRegistrationContext context)
{
    var grantTypes = context.Request.GrantTypes;
    if (grantTypes.Any(gt => gt != "authorization_code"))
    {
        context.SetError("Only authorization_code grant type is allowed");
        return Task.CompletedTask;
    }
    return base.ValidateGrantTypesAsync(context);
}
```

Always set `RequirePkce = true` in `SetClientDefaultsAsync`.

## 3. Using In-Memory Stores in Production

**Anti-pattern**: Running DCR in production without configuring `IClientConfigurationStore` to use a persistent store.

The default in-memory store loses all dynamically registered clients on restart. This means:
- Clients that registered successfully suddenly can't authenticate
- No audit trail of registered clients
- No sharing across multiple instances

**Fix**: Use the Entity Framework-backed store:

```bash
dotnet add package Duende.IdentityServer.Configuration.EntityFramework
```

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();
```

## 4. Storing Client Secrets in Plaintext

**Anti-pattern**: Persisting client secrets without hashing in your `IClientConfigurationStore` implementation.

Dynamically registered clients receive generated secrets. If these are stored in plaintext in your database, a data breach exposes all client credentials.

**Fix**: Always hash client secrets before storing them. Duende IdentityServer's `Secret` class supports `Sha256()` and `Sha512()` hashing. Ensure your `IClientConfigurationStore.AddAsync()` hashes secrets before persisting.

## 5. Accepting Software Statements from Unknown Issuers

**Anti-pattern**: Accepting software statements without validating the JWT signature against a known, trusted signing key.

If you blindly accept software statements, an attacker can forge a software statement with arbitrary claims and register a client with elevated privileges.

**Fix**: Always validate software statements against trusted signing keys:

```csharp
protected override async Task ValidateSoftwareStatementAsync(
    DynamicClientRegistrationContext context)
{
    var handler = new JsonWebTokenHandler();
    var validationResult = await handler.ValidateTokenAsync(
        context.Request.SoftwareStatement,
        new TokenValidationParameters
        {
            ValidIssuer = "https://trusted-authority.example.com",
            IssuerSigningKeys = await GetTrustedKeysAsync(),
            ValidateLifetime = true
        });

    if (!validationResult.IsValid)
    {
        context.SetError("Invalid software statement");
        return;
    }

    await base.ValidateSoftwareStatementAsync(context);
}
```

Never accept software statements signed by unknown issuers.

## 6. Additional Hardening Recommendations

- **Rate limit the DCR endpoint** to prevent abuse
- **Log all registration attempts** for audit purposes
- **Restrict redirect URIs to HTTPS** by overriding `ValidateRedirectUrisAsync`
- **Set conservative token lifetimes** for dynamically registered clients
- **Review registered clients periodically** and remove stale ones
- **Require software statements** if you want pre-approval of client registrations
