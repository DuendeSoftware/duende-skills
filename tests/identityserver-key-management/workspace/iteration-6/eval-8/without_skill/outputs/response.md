```csharp
builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.KeyPath = "/mnt/shared/identity-keys";
        options.KeyManagement.KeyCacheDuration = TimeSpan.FromHours(1);
    })
    // ...
```

**RSA key size:** to my knowledge Duende's automatic key management generates RSA keys at 2048 bits and doesn't expose a documented option for 4096 in `KeyManagement`. If you really need 4096-bit RSA you'd have to use static keys (`AddSigningCredential` with a 4096-bit certificate, setting `KeyManagement.Enabled = false`) or a custom `ISigningKeyStore`/key generation. Check the docs for your version, as I can't confirm an option for this.

Caveats: the shared path must be reachable and writable by all instances; keys are encrypted via Data Protection by default, so data protection must also be shared (same application name and key ring). Files on a share are not ideal for concurrency; the EF operational store is preferable.
