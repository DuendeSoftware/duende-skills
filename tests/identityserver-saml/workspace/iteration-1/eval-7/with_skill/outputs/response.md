# SAML NuGet Package and License Requirements

## NuGet Package

**No separate NuGet package is needed.** SAML 2.0 IdP support is **built into `Duende.IdentityServer`** itself. Your existing package reference is all you need:

```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
```

Just call `.AddSaml()` on the IdentityServer builder to enable SAML support:

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

## License Edition

SAML 2.0 IdP support requires the **Enterprise Edition** license. Without an Enterprise Edition license, the SAML endpoints will not be available and you may see licensing warnings at startup.

## Version Requirement

SAML support was introduced in **Duende IdentityServer version 8.0**. If you're on an earlier version (e.g., v7.x), you'll need to upgrade to v8.0 or later to use SAML features.
