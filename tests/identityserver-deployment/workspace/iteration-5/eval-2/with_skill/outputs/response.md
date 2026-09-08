# Intermittent CryptographicException across 3 Kubernetes replicas

## What's going wrong

The `CryptographicException` errors are a classic symptom of **ASP.NET Core Data Protection keys not being shared across your instances**.

With 3 replicas and no shared key persistence, each pod generates its own Data Protection key ring (by default in a local, ephemeral folder inside the container). Data Protection is used all over IdentityServer — encrypting/signing:

- Signing keys at rest (automatic key management)
- Persisted grants and server-side session data at rest
- External OIDC provider `state` payloads
- UI message payloads (logout/error context)
- Authentication cookies and anti-forgery tokens

When a request encrypted by pod A (e.g. a cookie or state value) is load-balanced to pod B, pod B can't find the key that protected it in its own key ring, so it throws:

```
CryptographicException: The key {id} was not found in the key ring
Error unprotecting ... with kid {id}
```

Because it depends on which pod handles the follow-up request, the failures are **intermittent** — exactly what you're seeing.

## Fix: configure Data Protection for a shared, durable store

Persist keys to a store every replica can read, set a consistent application name, and (recommended) protect the keys at rest.

```csharp
using Microsoft.AspNetCore.DataProtection;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

// Example using Redis as the shared key ring
var redis = ConnectionMultiplexer.Connect("redis:6379");

builder.Services.AddDataProtection()
    // 1. Persist the key ring to durable, SHARED storage
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys")
    // 2. (Recommended) protect keys at rest
    .ProtectKeysWithCertificate(LoadCert())
    // 3. Consistent application name across ALL replicas
    .SetApplicationName("My.IdentityServer");
```

Other `PersistKeysTo*()` targets work equally well depending on your infra:

- `.PersistKeysToDbContext<T>()` (EF Core / SQL)
- `.PersistKeysToAzureBlobStorage(...)` + `.ProtectKeysWithAzureKeyVault(...)`
- `.PersistKeysToAWSSystemsManager(...)`

### Why each piece matters

1. **`.PersistKeysTo...()` to a shared store** — all 3 replicas read/write the same key ring, so a value protected on one pod can be unprotected on any other. **Never** rely on the default ephemeral / local-file keys for multi-instance.
2. **`.SetApplicationName("My.IdentityServer")`** — Data Protection isolates keys by application name (and, historically, by content root path). Without an explicit, **identical** name on every replica, pods isolate their keys from each other even when they share storage. It must be the same string on all instances and across restarts.
3. **Protect keys at rest** (certificate / Key Vault) — the key ring in Redis or a DB should itself be encrypted.
4. **Durable backing store** — if you use Redis, enable Redis persistence (RDB/AOF) so the key ring survives a Redis restart.

## Don't forget the IdentityServer signing key store

Data Protection is only half the multi-instance story. IdentityServer's **signing keys** (automatic key management) are, by default, written to the local **file system** — which is also per-pod. In Kubernetes that means each replica can mint tokens with a key the others don't publish in JWKS, causing intermittent token validation failures.

Share the signing keys too, via the EF **operational store** (which includes `ISigningKeyStore`) or a custom shared `ISigningKeyStore`:

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
        options.ConfigureDbContext = b =>
            b.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")))
    // ... in-memory config stores etc.
    ;
```

## Cross-cutting note

Data Protection isn't IdentityServer-specific — it's a **cross-cutting concern for all Duende SDKs** (IdentityServer *and* BFF). See Duende's general [ASP.NET Core Data Protection guidance](https://docs.duendesoftware.com/general/data-protection/), which applies the same rules everywhere.

## Summary

- Root cause: unshared Data Protection keys across replicas.
- Fix: `.PersistKeysTo<sharedStore>()` + `.SetApplicationName("...")` + protect keys at rest.
- Also share the IdentityServer signing key store (EF operational store, not the default file system).
- Never use ephemeral/file-system-local keys for a multi-instance deployment.
