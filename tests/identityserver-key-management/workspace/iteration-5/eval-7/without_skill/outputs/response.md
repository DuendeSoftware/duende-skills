# `The key was not found in the key ring` — Data Protection Not Shared

## Diagnosis

This exception comes from **ASP.NET Core Data Protection**, not from IdentityServer's signing keys directly. IdentityServer uses the Data Protection API to encrypt sensitive material, and Data Protection maintains its own set of keys (the "key ring").

By default, Data Protection stores its key ring in a location that is local to each machine/instance (and it's tied to the application's identity). In a load-balanced deployment with multiple instances:

- Instance A protects data using **its** Data Protection key.
- The request is later handled by instance B, which has a **different** key ring and therefore reports `The key {ID} was not found in the key ring`.

So the problem is that your Data Protection keys are **not shared** across the load-balanced instances.

## The fix

Configure Data Protection to persist its key ring to a **shared** location that all instances can read, and give the application a **stable, explicit name** so every instance uses the same key ring.

```csharp
using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDataProtection()
    // Persist the key ring to shared storage that all instances can access:
    .PersistKeysToFileSystem(new DirectoryInfo("/mnt/shared/dataprotection-keys"))
    // or .PersistKeysToDbContext<MyKeysDbContext>()
    // or .PersistKeysToAzureBlobStorage(...)

    // Ensure every instance uses the same application name (and key ring):
    .SetApplicationName("IdentityServer");
```

If you're on Azure, `PersistKeysToAzureBlobStorage` plus `ProtectKeysWithAzureKeyVault` is a common combination. On-prem, a shared network path or a database-backed store works well.

## Key points

- **`SetApplicationName`** must be the *same* string on every instance and must not change between deployments — Data Protection isolates key rings by application name.
- Choose a persistence provider that is genuinely shared and durable (database, blob storage, or a shared file share) rather than each instance's local disk.
- Once all instances share the same key ring, they can all decrypt what any instance protected, and the `CryptographicException` goes away.

After deploying this change, any data protected with the old per-instance keys may still fail to decrypt until it's reissued, but new data will be consistent across the cluster.
