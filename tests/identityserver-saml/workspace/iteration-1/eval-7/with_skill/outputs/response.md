# SAML Support in Duende IdentityServer: Package and License Requirements

## No Separate NuGet Package

SAML 2.0 Identity Provider support is **built into `Duende.IdentityServer`** — there is no separate NuGet package to install. If you already have the `Duende.IdentityServer` package referenced, you have SAML support available.

Just call `.AddSaml()` on the IdentityServer builder:

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

## Enterprise Edition License Required

SAML 2.0 IdP functionality requires the **Enterprise Edition** license. This is the highest tier that includes all IdentityServer features:

- **Starter** — Core OIDC/OAuth features
- **Business** — Adds Dynamic Client Registration, BFF, etc.
- **Enterprise** — Adds SAML 2.0 IdP support and all other features

Without an Enterprise license, calling `.AddSaml()` will produce licensing warnings and the SAML endpoints will not function.

## Version Requirements

SAML 2.0 IdP support was **introduced in version 8.0** of Duende IdentityServer. If you're on an earlier version (v7 or below), you'll need to upgrade to v8.0+ to use SAML features.

## Summary

| Question | Answer |
|---|---|
| Separate NuGet package? | No — built into `Duende.IdentityServer` |
| License edition? | Enterprise Edition |
| Minimum version? | v8.0 |