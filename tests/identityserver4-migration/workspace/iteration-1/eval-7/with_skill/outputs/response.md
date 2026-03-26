# Persisted Grants Decryption Failure After .NET Upgrade

## Root Cause: ASP.NET Core Data Protection

The issue is caused by **ASP.NET Core Data Protection**. IdentityServer uses Data Protection to encrypt the `Data` column in persisted grants (refresh tokens, authorization codes, etc.). When Data Protection can no longer decrypt previously encrypted data, those grants become unreadable.

## Why This Happened

ASP.NET Core Data Protection uses an **application discriminator** (application name) to isolate encryption keys between applications. By default, the application name is derived from the **content root path**.

The default content root path changed between .NET versions:

| .NET Version | Default Content Root |
|-------------|---------------------|
| .NET Core 3.1 – .NET 5 | Content root path **without** trailing separator |
| .NET 6 | Content root path **with** trailing separator (breaking change!) |
| .NET 7+ | Content root path **without** trailing separator |

When you upgraded from .NET 6 to .NET 8, the default application discriminator changed (or if you went from .NET 3.1 to .NET 6 to .NET 8, it flipped twice). This means Data Protection treats the pre-upgrade and post-upgrade instances as **different applications**, and the encryption keys from the old instance are not used by the new instance — even if they're still physically present.

## The Fix

### Step 1: Set an Explicit Application Name

Add `SetApplicationName()` to your Data Protection configuration with an explicit, stable value:

```csharp
builder.Services.AddDataProtection()
    .SetApplicationName("YourIdentityServer")  // Must match across all instances and versions
    .PersistKeysToDbContext<DataProtectionKeyContext>();  // Or your chosen key storage
```

The application name you choose doesn't matter as long as it's:
- **Consistent** across all deployed instances
- **Stable** across .NET version upgrades
- **The same** as what the old deployment was using (or you accept that old data is lost)

### Step 2: Ensure Old Data Protection Keys Are Still Available

Data Protection uses encryption keys stored in a key ring. If these keys have been deleted or are inaccessible, the data they encrypted cannot be recovered regardless of the application name fix.

Verify that:
- The old Data Protection key files (XML files) are still present if using file-based storage
- The old key rows are still in the database if using `PersistKeysToDbContext`
- No key cleanup or rotation has removed the old keys
- The key ring is accessible from the new deployment (same file path, same database, same Azure Blob container, etc.)

### Step 3: If You Can't Recover Old Keys

If the old Data Protection keys are truly gone, the encrypted persisted grants cannot be recovered. In this case:
- Users with active refresh tokens will need to re-authenticate
- Authorization codes in flight will fail
- Clear the orphaned persisted grants from the database

## Prevention for Future Upgrades

Always configure `SetApplicationName()` explicitly — this prevents the issue from recurring on any future .NET version upgrade.
