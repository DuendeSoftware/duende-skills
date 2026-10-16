# SAML SP validation requirements

Every SP store is wrapped with `ValidatingSamlServiceProviderStore<T>`. An SP failing validation is **treated as non-existent**. Checks:

- `EntityId` is present
- **≥ 1 ACS URL**, **HTTP-POST binding only** (HTTP-Redirect fails)
- **≥ 1 `AllowedScopes`**
- positive lifetimes (`AssertionLifetime` etc.)

Your SP, fixed:

```csharp
new SamlServiceProvider
{
    EntityId = "https://hr.example.com",
    DisplayName = "HR",
    AssertionConsumerServiceUrls =
    [
        new IndexedEndpoint
        {
            Location = "https://hr.example.com/sso",
            Binding = SamlBinding.HttpPost,
            Index = 0,
            IsDefault = true
        }
    ],
    AllowedScopes = ["openid", "profile", "email"],   // commonly forgotten
    RequireSignedAuthnRequests = false                // or true + Certificates = [...]
}
```

Other common causes:
- If `RequireSignedAuthnRequests = true` (the default global `WantAuthnRequestsSigned` is true), you need the SP's signing `Certificates`, otherwise requests are rejected.
- ACS in the AuthnRequest must match a registered one.
- Single logout URLs must use HTTP-Redirect.
- Clock skew: "response not yet valid" → adjust `DefaultClockSkew` (5 min default).
- `Enabled = false` rejects everything.
- Custom rules can be added through `ISamlServiceProviderConfigurationValidator`; the `AuthnRequestErrorInspector` callbacks help debug interop.
