# Running IdentityServer on Multiple Nodes (Load-Balanced) with SAML

Scaling IdentityServer horizontally introduces the classic distributed-systems requirement: no request can depend on in-memory state that only exists on the node that handled a previous request. For SAML specifically, there are a few areas to address.

## 1. Shared Data Protection keys

This is the most common cause of multi-node problems. ASP.NET Core uses Data Protection to encrypt cookies, tokens, and other protected payloads. By default each node generates its own key ring, so a cookie or protected value created on node A can't be decrypted on node B.

Persist the keys to a shared store and use a common application name:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redisConnection, "DataProtection-Keys")
    .SetApplicationName("identityserver");
```

Options include Redis, a shared database, a network file share, or Azure Blob Storage.

## 2. Consistent signing credentials

All nodes must sign with the same certificate/key so assertions and tokens issued by one node validate the same way as another. Load the same X.509 signing certificate on every node (e.g., from a certificate store or Key Vault) rather than generating a temporary one per instance.

## 3. Persistent, shared stores instead of in-memory

Anything you'd normally register as `AddInMemory...` should move to a persistent store shared by all nodes:

- Client / resource / service-provider configuration → a database (EF Core is the typical choice).
- Operational data such as grants, and any SAML session/logout state → a shared operational store (database or Redis).

In-memory registrations keep data per-process, so different nodes would see different data.

## 4. Sticky sessions (optional stopgap)

Enabling session affinity ("sticky sessions") on the load balancer routes a user consistently to the same node, which can mask some state-sharing issues. It's a band-aid, not a substitute for shared Data Protection keys and persistent stores — a node restart or scale-in still loses in-memory state.

## Summary

- Share Data Protection keys across nodes (most important).
- Use the same signing certificate everywhere.
- Replace in-memory stores with persistent, shared ones (EF Core / Redis).
- Terminate TLS and set forwarded-headers correctly so redirect URLs are generated with the right public host/scheme.

Verify the specific SAML session/state storage options against your SAML library's docs, since the exact store abstractions differ between implementations.
