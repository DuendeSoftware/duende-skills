```csharp
using System.IO;

builder.Services.AddDataProtection()
    .SetApplicationName("IdentityServer")
    .PersistKeysToFileSystem(new DirectoryInfo("/mnt/shared/dataprotection"));
    // + ProtectKeysWith... (certificate/Key Vault) so DP keys aren't plaintext on the share

builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = true;                          // automatic key management
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(60); // new key every 60 days
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(7);   // announced 7 days before activation
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(21);// kept 21 days after retirement
    options.KeyManagement.DeleteRetiredKeys = true;

    options.KeyManagement.DataProtectKeys = true;                  // encrypt keys at rest (default)
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";   // shared across instances
});
```
Lifecycle: announced (`PropagationTime`) → active (until `RotationInterval`) → retired (`RetentionDuration`, still in discovery for validation) → deleted.

Load-balancer notes: every instance must reach the same `KeyPath`, and — because `DataProtectKeys` is on — must share the same Data Protection key ring and application name, or they can't decrypt each other's signing keys. For production the EF Core operational store is an alternative to the file share (see `identityserver-stores`).
