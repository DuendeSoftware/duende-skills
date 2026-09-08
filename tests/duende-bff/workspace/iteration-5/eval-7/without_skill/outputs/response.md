# Random logouts across load-balanced instances

This is the classic ASP.NET Core Data Protection problem in a scaled-out deployment.

## What's happening

The authentication cookie is encrypted/signed using ASP.NET Core **Data Protection**. Out of the box, the Data Protection **key ring is kept in each instance's local memory** (or a local folder). Each of your three instances therefore has a *different* set of keys.

When a user authenticates on instance #1, their cookie is protected with instance #1's keys. If the load balancer later routes them to instance #2, that instance can't decrypt the cookie, treats them as unauthenticated, and they get "logged out" — seemingly at random, depending on which node they hit.

## The fix: a shared, persistent key ring

Configure Data Protection to store its keys in a location all instances share, and give every instance the same application name so they use the same keys:

```csharp
// Example: persist keys to a shared database via EF Core
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<AppDbContext>()
    .SetApplicationName("my-bff");
```

Other supported backends work equally well — choose whatever your environment already has:

```csharp
// Redis
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys")
    .SetApplicationName("my-bff");

// Azure Blob Storage (+ Key Vault to encrypt the keys at rest)
builder.Services.AddDataProtection()
    .PersistKeysToAzureBlobStorage(blobUri, credential)
    .ProtectKeysWithAzureKeyVault(keyId, credential)
    .SetApplicationName("my-bff");
```

The important parts:

- **Same key store** for all three instances.
- **Same `SetApplicationName`** on every instance (the app name is part of how keys are isolated).

## Also worth doing

- If you use a distributed/server-side session or cache, back it with a shared store (Redis, SQL) as well, so nothing important lives only in a single node's memory.
- Sticky sessions on the load balancer can *reduce* the symptom but don't fix the underlying issue — a shared key ring is the real solution and survives deploys and scale-in.

Once all nodes share the Data Protection keys, cookies issued by any instance are readable by the others and the random logouts stop.
