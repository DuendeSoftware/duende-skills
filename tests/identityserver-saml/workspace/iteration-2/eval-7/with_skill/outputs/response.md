# SAML Support in Duende IdentityServer — Package and License Requirements

## No Separate NuGet Package Needed

SAML 2.0 IdP support is **built into the `Duende.IdentityServer` package**. You do not need to install any additional NuGet package. If you already have `Duende.IdentityServer` referenced, just call `.AddSaml()` on the IdentityServer builder:

```csharp
builder.Services.AddIdentityServer()
    .AddSaml();
```

## License Requirement

SAML support requires the **Enterprise Edition** license. The Starter, Business, and Community editions do not include SAML functionality.

## Version Requirement

SAML 2.0 IdP support was introduced in **Duende IdentityServer version 8.0**. If you are on an earlier version (v7 or below), you will need to upgrade to v8.0 or later to use this feature.
