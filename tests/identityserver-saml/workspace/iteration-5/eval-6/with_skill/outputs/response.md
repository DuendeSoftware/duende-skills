# Running SAML on Multiple IdentityServer Nodes Behind a Load Balancer

In a multi-node deployment, any state that a SAML flow relies on **between requests** must be shared across nodes — because the load balancer can (and will) route the AuthnRequest, the login callback, and each SLO iframe callback to *different* nodes. If that state lives in a single node's memory, the flow breaks the moment a follow-up request lands elsewhere.

There are four things to get right:

## 1. Distributed SAML sign-in state — `ISamlSigninStateStore`

During SP-initiated SSO, IdentityServer parks the details of the inbound AuthnRequest (the "sign-in state") while the user authenticates, then rehydrates it on the callback to build the SAML Response. Configure a distributed **`ISamlSigninStateStore`** so this state is readable on whichever node handles `/Saml2/SSO/Callback`. Without it, the callback on a different node can't find the original request and the SSO fails.

## 2. Distributed SLO session tracking — `ISamlLogoutSessionStore`

Single Logout tracks which SPs have active sessions and which have responded to the front-channel iframe LogoutRequests. That per-logout session state must be shared, so configure a distributed **`ISamlLogoutSessionStore`**. Otherwise the node collecting an iframe `LogoutResponse` won't know about the logout session that another node started, and SLO can't complete.

## 3. Persistent SP configuration store (EF Core / Redis)

Service-provider registrations must be the same on every node. Use the **EF Core configuration store** (`AddConfigurationStore`) — or a custom/`Redis`-backed store — rather than `AddInMemorySamlServiceProviders`, which is per-process and dev-only.

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    });
```

> **Convenient default**: `AddOperationalStore()` automatically registers EF Core implementations of **both** `ISamlSigninStateStore` **and** `ISamlLogoutSessionStore`. So if you're already on the EF operational store, points 1 and 2 are handled for you — no separate registration needed.

## 4. Shared Data Protection keys

All nodes must share the same **ASP.NET Core Data Protection** key ring so protected payloads (cookies, tokens, and SAML state protected with data protection) created on one node can be read on another. Persist keys to a shared location (a shared file share, database, Redis, or Azure Blob Storage) and set a common application name:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys")
    .SetApplicationName("identityserver");
```

This also keeps SAML/OIDC **signing keys** consistent, since Automatic Key Management stores its keys via the operational store and shares them across the cluster.

## Summary checklist

| Concern | What to configure |
|---------|-------------------|
| Sign-in state across nodes | `ISamlSigninStateStore` (or `AddOperationalStore`) |
| SLO session tracking across nodes | `ISamlLogoutSessionStore` (or `AddOperationalStore`) |
| SP configuration | EF Core `AddConfigurationStore` (not in-memory) |
| Key/cookie sharing | Shared Data Protection key ring + common app name |

The core principle: **in-memory anything is unsafe for multi-node.** Without distributed stores, SSO and SLO state is lost the instant a subsequent request hits a different node.
