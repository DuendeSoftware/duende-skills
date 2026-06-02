# Deploying IdentityServer SAML on Multiple Nodes

When running IdentityServer behind a load balancer, you need to ensure consistent state across nodes.

## Key Considerations

### 1. Session State

IdentityServer uses cookies for session management. Ensure cookie encryption keys are shared:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys");
```

### 2. Signing Keys

All nodes must share the same signing credentials for SAML assertions:

```csharp
builder.Services.AddIdentityServer()
    .AddSigningCredential(certificate);
```

Store certificates in a shared location like Azure Key Vault.

### 3. Configuration Store

Use a database-backed store for service provider configuration:

```csharp
services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    });
```

### 4. Operational Data

Use a distributed cache or database for operational data like grants and sessions:

```csharp
services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    });
```

### 5. Sticky Sessions (Alternative)

If you can't distribute all state, configure your load balancer for sticky sessions. However, this reduces availability.

## Summary

- Share Data Protection keys across nodes
- Use persistent stores for configuration and operational data
- Ensure signing keys are consistent
- Consider distributed caching for performance
