# Persisted Grants Decryption Failure After .NET Upgrade

## Root Cause: ASP.NET Core Data Protection

The issue is **ASP.NET Core Data Protection**. Persisted grants in IdentityServer are encrypted using Data Protection. When you upgraded from .NET 6 to .NET 8, the default application discriminator (application name) changed, which caused key isolation — the new application instance cannot find the old Data Protection keys.

## Why the Default Application Name Changed

The default application name is derived from the content root path. Between .NET versions, this changed:

- **.NET 3.1–5**: content root path without trailing separator
- **.NET 6**: content root path **with** trailing separator (breaking change)
- **.NET 7+**: content root path without trailing separator

Because the application name is used to isolate key rings, a different application name means the .NET 8 instance creates a new, separate key ring and cannot read keys from the .NET 6 key ring.

## Fix: Set an Explicit Application Name

Add an explicit `SetApplicationName()` call to your Data Protection configuration:

```csharp
builder.Services.AddDataProtection()
    .SetApplicationName("YourIdentityServer")
    .PersistKeysToDbContext<DataProtectionKeyContext>(); // or PersistKeysToFileSystem, etc.
```

This ensures the application name stays constant across .NET version upgrades.

## Ensure Old Keys Are Still Accessible

Even with the correct application name, the old Data Protection keys must still be accessible:

1. **Do not delete old Data Protection keys** from your key repository (database, file system, Azure Blob Storage, etc.)
2. If keys were stored on the file system, make sure the same key directory is mounted in the new deployment
3. If you were using the default ephemeral key store (in-memory), your old keys are already lost and the encrypted persisted grants are unrecoverable — you'll need to clear the persisted grants table and have users re-authenticate

## Preventive Measure

Always set `SetApplicationName()` explicitly in production deployments to prevent this issue during future framework upgrades.
