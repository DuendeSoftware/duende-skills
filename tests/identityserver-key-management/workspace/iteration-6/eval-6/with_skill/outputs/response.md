**Phase 2: sign with the new key; keep the old key for validation.**

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.Enabled = false;
});

var oldKey = LoadOldKey();
var newKey = LoadNewKey();

idsvrBuilder.AddSigningCredential(newKey, SecurityAlgorithms.RsaSha256);   // RS256, now signs
idsvrBuilder.AddValidationKey(oldKey, SecurityAlgorithms.RsaSha256);       // still published in JWKS for validation
```

This swaps the roles from Phase 1 (old = signing, new = validation). Because caches already contain the new key, tokens signed by it validate everywhere.

**Wait** until all tokens signed with the old key have expired (e.g. 1 hour default access token lifetime, longer for identity tokens/JWT-based flows you use).

**Phase 3:** remove the old key:

```csharp
idsvrBuilder.AddSigningCredential(LoadNewKey(), SecurityAlgorithms.RsaSha256);
```
