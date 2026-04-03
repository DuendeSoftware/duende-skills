Here are the most common security mistakes with DCR and how to avoid them:

### 1. Exposing the DCR endpoint without authentication

The `/connect/dcr` endpoint allows creating new OAuth clients. If left unauthenticated, **anyone on the internet can register clients** in your IdentityServer. This is the most critical mistake.

**Fix:** Always apply an authorization policy to `MapDynamicClientRegistration()`:

```csharp
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");
```

Configure JWT bearer authentication with a scope check so only authorized callers can register clients.

### 2. Allowing dynamically registered clients to use any grant type

By default, if you don't restrict grant types in your DCR validator, clients can request dangerous grant types like `client_credentials` or `implicit`. A malicious caller could register a client with broad permissions.

**Fix:** Extend `DynamicClientRegistrationValidator` and override `ValidateGrantTypesAsync` to restrict allowed grant types. At minimum, only allow `authorization_code` and enforce PKCE:

```csharp
protected override Task ValidateGrantTypesAsync(DynamicClientRegistrationContext context)
{
    if (context.Request.GrantTypes.Any(gt => gt != "authorization_code"))
    {
        context.SetError("Only authorization_code grant type is allowed");
        return Task.CompletedTask;
    }
    return base.ValidateGrantTypesAsync(context);
}

protected override Task SetClientDefaultsAsync(DynamicClientRegistrationContext context)
{
    context.Client.RequirePkce = true;
    return base.SetClientDefaultsAsync(context);
}
```

### 3. Using in-memory stores for DCR clients in production

In-memory stores lose all dynamically registered clients when the application restarts. This means clients lose access and must re-register, which breaks production systems.

**Fix:** Use the Entity Framework-backed store:

```bash
dotnet add package Duende.IdentityServer.Configuration.EntityFramework
```

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();
```

### 4. Storing client secrets in plaintext

Dynamically registered clients receive generated secrets. If your `IClientConfigurationStore` implementation stores these secrets in plaintext, a database breach exposes all client credentials.

**Fix:** Ensure your store hashes client secrets (SHA-256 or better) before persisting them. The built-in Entity Framework store handles this automatically. If you implement a custom `IClientConfigurationStore`, make sure secrets are stored as hashed values, never plaintext.

### 5. Accepting software statements from unknown issuers

Software statements are signed JWTs containing pre-approved client metadata. If you don't validate the issuer and signing keys, a malicious actor could forge a software statement to register a client with elevated privileges.

**Fix:** Override `ValidateSoftwareStatementAsync` and validate the JWT against trusted signing keys:

```csharp
protected override async Task ValidateSoftwareStatementAsync(
    DynamicClientRegistrationContext context)
{
    var handler = new JsonWebTokenHandler();
    var result = await handler.ValidateTokenAsync(
        context.Request.SoftwareStatement,
        new TokenValidationParameters
        {
            ValidIssuer = "https://trusted-authority.example.com",
            IssuerSigningKeys = await GetTrustedKeysAsync(),
            ValidateLifetime = true
        });

    if (!result.IsValid)
    {
        context.SetError("Invalid software statement");
        return;
    }
    
    await base.ValidateSoftwareStatementAsync(context);
}
```

Never accept software statements signed by unknown or unvalidated issuers.

### Summary checklist

| Anti-Pattern | Risk | Fix |
|---|---|---|
| Unauthenticated DCR endpoint | Unauthorized client registration | `RequireAuthorization()` with scope check |
| Unrestricted grant types | Malicious clients with broad permissions | Custom `DynamicClientRegistrationValidator` |
| In-memory stores in production | Data loss on restart | `AddClientConfigurationStore()` (EF) |
| Plaintext secret storage | Credential exposure on breach | Hash secrets in your `IClientConfigurationStore` |
| Unvalidated software statements | Forged client metadata | Validate JWT issuer and signing keys |
