Likely **Data Protection**. Persisted grants (e.g. refresh tokens, consent in some stores) and some cookies/state are protected with ASP.NET Core Data Protection. The key ring is scoped by the **application discriminator** (app name/content root path) and storage location. After the move, the application discriminator or key location changed (different content root/application name, new machine, keys not persisted), so the new app can't decrypt data protected by the old keys.

Fix:
```csharp
builder.Services.AddDataProtection()
    .SetApplicationName("IdentityServer")   // same as before
    .PersistKeysToFileSystem(new DirectoryInfo(@"/shared/keys"))
    .ProtectKeysWithCertificate(cert);
```
- Find the old key ring (file system, `%LOCALAPPDATA%\ASP.NET\DataProtection-Keys`, registry, blob, DB) and point the new app at it.
- Set `SetApplicationName` to whatever the old discriminator was (default is the content root path; use that old value).
- Keep keys persisted and shared across all instances.
- If keys are lost, existing grants can't be recovered: users must re-authenticate; clear invalid grants from the PersistedGrants table.
- Also check the grant protection changes in newer versions—some grants hashed (handle stored as hash) so verify format compatibility.
