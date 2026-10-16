**Phase 1: enable automatic key management, but keep signing with the static key.** A statically registered signing credential takes precedence over automatic keys, while key management begins creating and announcing keys in discovery.

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = true;
});

var oldKey = GetSigningKeyFromVault();
idsvrBuilder.AddSigningCredential(oldKey, SecurityAlgorithms.RsaSha256);
```

**Wait** until all APIs and clients have refreshed their JWKS caches (default 24h) so they know the new automatic keys.

Next steps:
- **Phase 2:** remove `AddSigningCredential`; keep the vault key as a validation key so previously issued tokens still validate:
  ```csharp
  idsvrBuilder.AddValidationKey(GetSigningKeyFromVault(), SecurityAlgorithms.RsaSha256);
  ```
  Wait until tokens signed with the static key have expired.
- **Phase 3:** drop the validation key; only `KeyManagement.Enabled = true` remains.

For multi-instance deployments ensure keys are in a shared store (EF operational store) and Data Protection is shared with a fixed application name.
