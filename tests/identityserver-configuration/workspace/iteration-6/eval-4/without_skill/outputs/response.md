```csharp
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/mnt/shared/identity-keys/dp"))
    .SetApplicationName("IdentityServer");

builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = true;
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(60);
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(7);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(21);
    options.KeyManagement.DataProtectKeys = true;
    options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";
});
```
`KeyPath` stores keys on the shared file path; `DataProtectKeys` encrypts them at rest using ASP.NET Data Protection. All instances must share the same data protection key ring and application name, otherwise they can't decrypt each other's keys. Consider a database store (`ISigningKeyStore`) for production instead of a file share.
