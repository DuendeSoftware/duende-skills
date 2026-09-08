# Intermittent CryptographicException with 3 IdentityServer replicas

## The root cause

This is almost always **ASP.NET Core Data Protection keys not being shared between your instances**.

By default, Data Protection stores its key ring in a local, per-instance location (a folder inside the container, or `%LOCALAPPDATA%`). With 3 replicas, each pod generates and holds its **own** keys. Data Protection is what encrypts/signs things like authentication cookies, `state` values used in OIDC flows, anti-forgery tokens, and other protected payloads.

When a request protected by pod A is routed by the load balancer to pod B, pod B doesn't have the key that was used, and you get:

```
CryptographicException: The key {id} was not found in the key ring
```

Since it depends on which replica serves each request, it happens **intermittently** — matching your symptom.

## The fix: share the key ring

Configure Data Protection to persist keys to a **shared, durable store** that all replicas use, and give the app a stable application name.

### Example with Redis

```csharp
using Microsoft.AspNetCore.DataProtection;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

var redis = ConnectionMultiplexer.Connect("redis:6379");

builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys")
    .SetApplicationName("My.IdentityServer");
```

### Example with a database (EF Core)

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<MyKeysDbContext>()
    .SetApplicationName("My.IdentityServer");
```

### Other options

- `PersistKeysToAzureBlobStorage(...)` + `ProtectKeysWithAzureKeyVault(...)` on Azure
- `PersistKeysToAWSSystemsManager(...)` on AWS
- A shared file share / persistent volume mounted into every pod (works but less robust than Redis/DB)

## Why each part matters

1. **`PersistKeysTo...` to shared storage** — every replica reads/writes the same key ring, so any pod can decrypt what another pod encrypted.
2. **`SetApplicationName("...")`** — Data Protection isolates keys by application name. If it isn't set explicitly and identically on every replica, the pods will still isolate their keys even when pointed at the same store. Use the **same** name everywhere and keep it stable across restarts/deploys.
3. **Encrypt the keys at rest** (optional but recommended) — e.g. `ProtectKeysWithCertificate(...)` or Azure Key Vault, so the stored key ring isn't in plaintext.

Do **not** rely on the default in-memory/local-file keys for a multi-instance deployment.

## Bonus: signing keys

Separately from Data Protection, if you use IdentityServer's automatic signing-key management, make sure those signing keys are also stored in a shared store (e.g. the EF operational store) rather than per-pod local files — otherwise tokens signed by one replica may not validate against another. But the CryptographicException you're seeing is the Data Protection issue above.
