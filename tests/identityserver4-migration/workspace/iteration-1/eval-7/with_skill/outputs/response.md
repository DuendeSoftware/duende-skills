# Persisted Grants Cannot Be Decrypted After .NET Upgrade

## Root Cause: ASP.NET Core Data Protection

The root cause of your decryption failure is **ASP.NET Core Data Protection**. IdentityServer uses Data Protection to encrypt the `Data` column in persisted grants. When the Data Protection configuration changes between .NET versions, previously encrypted data becomes unreadable.

## What Changed

The **default application name** (also called the application discriminator or content root path discriminator) **changed between .NET versions**:

- **.NET 3.1–5**: Content root path **without** trailing path separator
- **.NET 6**: Content root path **with** trailing path separator (breaking change)
- **.NET 7+**: Content root path **without** trailing path separator

Since you upgraded from .NET 6 to .NET 8, the default application discriminator changed from the content root path with a trailing separator (`.NET 6`) to without one (`.NET 8`). This means Data Protection treats the .NET 8 instance as a different application, isolating it from the keys generated under .NET 6.

## Fix

Call `SetApplicationName()` on `AddDataProtection()` with an explicit, fixed application name that will remain stable across .NET version upgrades:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionKeyContext>() // or your persistent store
    .SetApplicationName("YourIdentityServer");         // explicit, stable name
```

This ensures Data Protection uses a consistent application discriminator regardless of the .NET version or hosting path.

## Ensure Old Keys Are Accessible

You must also ensure that the **old Data Protection keys are still accessible** — not deleted or rotated away. Data Protection needs the original key ring to decrypt data that was encrypted with those keys. If you are using:

- **File system key storage**: Ensure the key XML files from the old deployment are still present in the key directory.
- **Database storage** (`PersistKeysToDbContext`): Ensure the key rows haven't been purged.
- **Azure Blob Storage**: Ensure the blob hasn't been overwritten.
- **Default (ephemeral/in-memory)**: If no persistent store was configured, keys were lost when the old process stopped — and the encrypted data is unfortunately unrecoverable. Configure a persistent key store going forward.

After setting the application name and confirming key availability, restart IdentityServer and your persisted grants should decrypt successfully.
