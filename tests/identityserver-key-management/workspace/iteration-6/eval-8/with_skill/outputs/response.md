```csharp
builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";   // shared file system store
        options.KeyManagement.KeyCacheDuration = TimeSpan.FromHours(1); // default is 24 hours
        options.KeyManagement.RsaKeySize = 4096;                        // default is 2048
    })
    // ...
```

Notes:
- `KeyPath` must be readable and writable by every instance. The default is `{ContentRootPath}/keys`; keep it out of source control.
- Keys are encrypted at rest with Data Protection (`DataProtectKeys = true`), so on a multi-instance deployment you must also share Data Protection keys and set `SetApplicationName`; otherwise `The key {ID} was not found in the key ring` occurs.
- A shorter `KeyCacheDuration` means instances see new/deleted keys faster; keep `PropagationTime` longer than your clients' JWKS cache.
- `RsaKeySize` only applies to newly generated RSA keys; existing keys keep their size until rotation. 4096-bit signing is slower and larger; confirm you need it (2048 is the usual default).
- A database store (`AddOperationalStore`) is the recommended option for load-balanced setups.
