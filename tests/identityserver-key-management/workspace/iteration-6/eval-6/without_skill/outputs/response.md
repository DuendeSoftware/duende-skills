Phase 2: new key signs, old key stays only for validation.

```csharp
using Microsoft.IdentityModel.Tokens;

builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.Enabled = false;
    })
    .AddSigningCredential(LoadNewKey(), SecurityAlgorithms.RsaSha256)   // signs from now on
    .AddValidationKey(LoadOldKey(), SecurityAlgorithms.RsaSha256)       // still published in JWKS, validates old tokens
    // ...clients, scopes
    ;
```

(`LoadNewKey()` returns an `X509Certificate2`; `AddValidationKey` accepts a certificate or `SecurityKey`.)

Phase 1 had `AddSigningCredential(LoadOldKey())` + `AddValidationKey(LoadNewKey())`. Phase 3, once all tokens signed by the old key have expired (and caches refreshed), remove `AddValidationKey(LoadOldKey())`.
