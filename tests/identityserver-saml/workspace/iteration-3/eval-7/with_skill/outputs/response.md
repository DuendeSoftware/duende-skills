# SAML Support Requirements in Duende IdentityServer

## NuGet Package

**No separate NuGet package is needed.** SAML 2.0 IdP support is built directly into the `Duende.IdentityServer` package. You just call `.AddSaml()` on the IdentityServer builder:

```csharp
builder.Services.AddIdentityServer()
    .AddSaml();
```

## License Edition

SAML support requires an **Advanced or Custom Edition** license. It is not available in the Starter or Community editions.

## Version

SAML 2.0 IdP support was introduced in **Duende IdentityServer v8.0**.

## .NET Version

Duende IdentityServer v8.0 targets **.NET 10** (`net10.0`), as shown in the project file:

```xml
<TargetFramework>net10.0</TargetFramework>
<PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
```

## Summary

| Requirement | Value |
|-------------|-------|
| NuGet Package | `Duende.IdentityServer` (built-in, no separate package) |
| License | Advanced or Custom Edition |
| Minimum Version | 8.0 |
| .NET Framework | .NET 10 |
