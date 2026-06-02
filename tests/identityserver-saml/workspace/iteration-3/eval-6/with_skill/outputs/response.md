# Multi-Node SAML Deployment Configuration

When deploying Duende IdentityServer behind a load balancer on multiple nodes, SAML flows require distributed state management. Without it, SSO and SLO state is lost when requests hit different nodes.

## Required Distributed Stores

### 1. ISamlSigninStateStore — SSO State

During SP-initiated SSO, IdentityServer stores state (the AuthnRequest, relay state, etc.) between receiving the request and completing authentication. This must be shared across nodes:

```csharp
// Register a distributed sign-in state store (e.g., Redis or EF Core implementation)
builder.Services.AddTransient<ISamlSigninStateStore, RedisSamlSigninStateStore>();
```

Without this, if a user starts SSO on node A but the callback hits node B, the flow fails.

### 2. ISamlLogoutSessionStore — SLO Session Tracking

IdentityServer tracks which SPs have active SAML sessions so it can notify them during SLO. This must be distributed:

```csharp
// Register a distributed logout session store
builder.Services.AddTransient<ISamlLogoutSessionStore, RedisSamlLogoutSessionStore>();
```

Without this, a node handling logout won't know about sessions established on other nodes.

### 3. SP Configuration Store

Use EF Core (or another persistent store) for service provider data — not in-memory:

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });
```

### 4. Data Protection Key Sharing

Ensure ASP.NET Core Data Protection keys are shared across all nodes (for cookie encryption, anti-forgery tokens):

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys")
    .SetApplicationName("IdentityServer");
```

### 5. Signing Key Material

All nodes must use the same signing keys. Store them in a shared location (database, Azure Key Vault, etc.).

## Summary

| Component | Interface/Config | Why |
|-----------|-----------------|-----|
| SSO state | `ISamlSigninStateStore` | AuthnRequest state across nodes |
| SLO sessions | `ISamlLogoutSessionStore` | Track active SP sessions |
| SP config | EF Core config store | Shared SP registrations |
| Keys | Data Protection + signing keys | Consistent encryption/signing |

Without distributed stores for `ISamlSigninStateStore` and `ISamlLogoutSessionStore`, SSO/SLO state is lost across nodes, causing intermittent failures.
