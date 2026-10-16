**Cause:** Duende IdentityServer encrypts its automatic signing keys at rest with ASP.NET Core Data Protection. By default the Data Protection key ring is stored per machine (e.g. `~/.aspnet/DataProtection-Keys` or in-container), and the application discriminator is derived from the content root path. With several instances each has its own key ring (or a different app name), so an instance can't decrypt a signing key written by another one, hence "The key was not found in the key ring".

**Fix:** share the Data Protection key ring and use the same application name on all instances.

```csharp
using Microsoft.AspNetCore.DataProtection;

builder.Services.AddDataProtection()
    .SetApplicationName("MyIdentityServer")
    .PersistKeysToFileSystem(new DirectoryInfo("/mnt/shared/dp-keys"))   // or PersistKeysToDbContext / Azure Blob / Redis
    .ProtectKeysWithCertificate(cert);                                    // encrypt the ring at rest
```

Database alternative:

```csharp
builder.Services.AddDbContext<DataProtectionKeyContext>(o => o.UseSqlServer(cs));
builder.Services.AddDataProtection()
    .SetApplicationName("MyIdentityServer")
    .PersistKeysToDbContext<DataProtectionKeyContext>();
```

Also store the signing keys centrally (`AddOperationalStore`) rather than the local `~/keys` directory. After fixing, existing signing keys encrypted with a lost ring are unrecoverable: delete them from the `SigningKeys` table so new ones are generated.
