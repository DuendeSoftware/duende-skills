Phase 1 of the migration: turn on automatic key management so new keys are created and *published* in discovery, but keep your vault key as the *signing* credential. Clients and APIs thus learn the new keys before they sign anything.

```csharp
builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.Enabled = true;
    })
    .AddSigningCredential(GetSigningKeyFromVault(), SecurityAlgorithms.RsaSha256)  // static key still signs
    // ...clients, scopes
    ;
```

`AddSigningCredential` takes precedence for signing while automatic keys are still created, stored and added to the discovery document as validation keys. Also:
- Make sure key storage and data protection are shared across instances (EF operational store).
- Wait longer than the longest JWKS cache of your clients/APIs.

Phase 2 (later): remove the static `AddSigningCredential`, so automatic keys sign. Keep the old key with `.AddValidationKey(oldKey)` until all tokens signed with it have expired. Phase 3: remove the validation key.
