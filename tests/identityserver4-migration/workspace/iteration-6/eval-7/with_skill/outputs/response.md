## What went wrong: Data Protection key discontinuity

Persisted grants' `Data` column is encrypted with ASP.NET Core Data Protection. Decryption fails if the old keys aren't available or the **application discriminator** changed. The default discriminator is the content root path, and it changed across .NET versions:
- .NET Core 3.1–5: content root without trailing separator
- .NET 6: **with** trailing separator (breaking change)
- .NET 7+: without trailing separator

So moving from .NET 6 (IS4) to .NET 8 (Duende) changes the default application name and the new app can't use the old key ring's data (assuming it is even finding the same keys). Also, if no persistent repository was configured, keys were in memory and lost at restart.

### Fix
Set the application name explicitly to the **old effective value**, and persist keys:
```csharp
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionKeyContext>()   // or file system / blob storage
    .SetApplicationName("YourIdentityServer");            // must equal the old discriminator
```
For the old .NET 6 deployment that means the content root path **with trailing separator** (e.g. `/app/`, `C:\inetpub\app\`). Make sure the old key ring is the one loaded by the new app. Share keys across all instances.

If the old keys are truly gone, the stored grants can't be decrypted — users must sign in again, and you should clear the unreadable grants.

Prevent recurrence: run the Migration Analysis Tool before migrating — it flags missing/path-based application names and ephemeral key repositories (`(not set)`).
