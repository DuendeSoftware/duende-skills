# External Authentication Handler Compatibility After Migration

Your external authentication providers (Google OAuth, WS-Federation, Sustainsys.Saml2) will continue to work conceptually, but **their NuGet packages must be updated** to versions compatible with the new .NET version. IdentityServer4 ran on .NET Core 3.1 or .NET 5 — Duende IdentityServer v7 requires .NET 8 or .NET 10. Authentication handlers compiled against older ASP.NET Core versions may fail to load at runtime on the new framework.

## Handler-by-Handler Assessment

### Google OAuth (`Microsoft.AspNetCore.Authentication.Google`)

This is a Microsoft-maintained package that ships with the ASP.NET Core shared framework. When you update your target framework to `net8.0` or `net10.0`, the matching version is included automatically. No separate NuGet package update is needed — it comes with the framework.

### WS-Federation (`Microsoft.AspNetCore.Authentication.WsFederation`)

This handler **needs a NuGet package update** to match your target .NET version:

```xml
<!-- For net8.0 -->
<PackageReference Include="Microsoft.AspNetCore.Authentication.WsFederation" Version="8.0.0" />

<!-- For net10.0 -->
<PackageReference Include="Microsoft.AspNetCore.Authentication.WsFederation" Version="10.0.0" />
```

The WS-Federation handler is not part of the shared framework — it ships as a standalone NuGet package and must be explicitly updated.

### SAML2P (`Sustainsys.Saml2`)

Sustainsys.Saml2 needs a compatible version for .NET 8+. The package has undergone significant API changes across major versions:

- **Sustainsys.Saml2 v2.x** — supports .NET Core 3.1 / .NET 5 (your current version likely)
- **Sustainsys.Saml2 v3.x** — rebuilt for modern .NET (.NET 8+)

```xml
<!-- Update to a version compatible with your target framework -->
<PackageReference Include="Sustainsys.Saml2.AspNetCore2" Version="3.0.0" />
```

Check the [Sustainsys.Saml2 releases](https://github.com/Sustainsys/Saml2/releases) for the latest compatible version. Be aware of breaking API changes in the configuration — the options setup may need adjustment.

## Post-Migration Verification

**Test all external login flows end-to-end after migration.** Specifically:

1. **Google login** — initiate login via Google, verify callback, check claims
2. **WS-Federation login** — initiate login via your Azure AD WS-Fed provider, verify the SAML token processing
3. **SAML2P login** — initiate login via the SAML2P provider, verify assertion processing and attribute mapping
4. **Error handling** — test with invalid/expired tokens to verify error flows still work correctly

Missing or incompatible handlers will cause runtime errors when users attempt to authenticate via those schemes. The errors may not appear until a user actually clicks "Sign in with [provider]", so automated testing of all external login paths is essential.

## Detection with the Migration Analysis Tool

If you run the Migration Analysis Tool (Step 0 of the migration) against your current IdentityServer4 instance, it will list all registered authentication schemes and flag non-Microsoft, non-IdentityServer4 handlers that may need attention. This gives you a complete inventory before you start.
