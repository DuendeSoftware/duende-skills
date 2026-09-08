# Persisted grants won't decrypt after upgrading .NET 6 → .NET 8

## Root cause: ASP.NET Core Data Protection

This is not really an IdentityServer bug — it's **ASP.NET Core Data Protection**. IdentityServer stores the `Data` column of persisted grants (and other sensitive payloads) encrypted with the Data Protection stack. To decrypt a payload, Data Protection must use the **same application identity (discriminator) and the same key ring** that encrypted it. When either changes, decryption fails and your persisted grants become unreadable.

## Why the .NET upgrade broke it

By default, Data Protection **isolates keys per application using a discriminator derived from the content root path**. That default value has changed across .NET versions:

- .NET 3.1–5: content root path **without** a trailing separator
- .NET 6: content root path **with** a trailing directory separator (a behavior change)
- .NET 7+: back to **without** the trailing separator

So when you moved from .NET 6 to .NET 8, the automatically computed application name changed. Data Protection concluded it was a "different application," isolated the keys, and could no longer decrypt data that was protected under the .NET 6 discriminator — even though the key material itself may still exist.

## The fix

**1. Set an explicit application name** so the discriminator no longer depends on the framework's default (the path):

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionKeyContext>()   // or file system / Azure Blob
    .SetApplicationName("YourIdentityServer");            // stable, version-independent
```

Use the **same** application name you effectively had before the break (if you never set one, you may need to reproduce the old default so existing data decrypts — then standardize on the explicit name going forward). From now on, framework upgrades won't change the discriminator.

**2. Make sure the old Data Protection keys are still available.** `SetApplicationName` only helps if the original key ring that encrypted the grants is still present and not deleted or rotated away. Point Data Protection at the **same persistent key repository** you used before (`PersistKeysToDbContext`, `PersistKeysToFileSystem`, `PersistKeysToAzureBlobStorage`, …). If the keys were stored in-memory (ephemeral) or were purged, the data genuinely cannot be recovered.

## Prevention going forward

- Always call `SetApplicationName()` explicitly.
- Always configure a **persistent** key repository (never rely on the ephemeral in-memory store in production).
- Keep old keys available through framework and hosting changes so previously-encrypted grants, cookies, and antiforgery tokens remain readable.
