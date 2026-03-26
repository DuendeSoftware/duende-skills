# External Authentication Provider Compatibility After Migration

## Third-Party Authentication Handlers Need Updates

When migrating from IdentityServer4 (on .NET Core 3.1 / .NET 5) to Duende IdentityServer (on .NET 8+), all third-party authentication handlers must be updated to versions compatible with the new ASP.NET Core version. The handlers themselves are ASP.NET Core authentication middleware — they have no dependency on IdentityServer4 or Duende, but they do depend on specific ASP.NET Core versions.

## Your Specific Handlers

### 1. Google OAuth (`Microsoft.AspNetCore.Authentication.Google`)

This is a first-party Microsoft package. Update it to match your target framework:

```xml
<!-- For net8.0 -->
<PackageReference Include="Microsoft.AspNetCore.Authentication.Google" Version="8.0.0" />
```

On .NET 8+, the social auth packages are included in the ASP.NET Core shared framework, so you may not even need an explicit package reference — just verify the `AddGoogle()` extension method is available.

### 2. WS-Federation (`Microsoft.AspNetCore.Authentication.WsFederation`)

This is also a Microsoft package, but it's **not** included in the shared framework — you need an explicit package reference:

```xml
<!-- For net8.0 -->
<PackageReference Include="Microsoft.AspNetCore.Authentication.WsFederation" Version="8.0.0" />
```

**Important:** The WS-Federation package must match the target framework version. A .NET Core 3.1 version will not load on .NET 8.

### 3. SAML2P (Sustainsys.Saml2)

Sustainsys.Saml2 is a third-party package. You need a version compatible with .NET 8+:

```xml
<!-- Check NuGet for the latest compatible version -->
<PackageReference Include="Sustainsys.Saml2.AspNetCore2" Version="2.9.x" />
```

**Important notes:**
- Sustainsys.Saml2 has had breaking API changes between major versions
- The package name may have changed (e.g., `Sustainsys.Saml2.AspNetCore2` vs older naming)
- Review the Sustainsys changelog for .NET 8 compatibility and any required code changes
- If Sustainsys doesn't support .NET 8, consider alternatives like `ITfoxtec.Identity.Saml2` or the Duende SAML component

## Testing After Migration

**Test all external login flows end-to-end after migration.** Missing or incompatible handlers will cause runtime errors (not compile-time errors) when users attempt to authenticate via those schemes.

For each provider:
1. Click the external login button
2. Verify the redirect to the external provider works
3. Complete authentication at the provider
4. Verify the callback to IdentityServer succeeds
5. Verify claims mapping and user provisioning still work correctly

## Common Issues

- **Handler fails to load at runtime** — The handler assembly was compiled against an older ASP.NET Core version. Update the NuGet package.
- **Claims not mapped correctly** — Some providers changed their claim types between versions. Check `ClaimActions` configuration.
- **Redirect URI mismatch** — If your IdentityServer URL changed, update the redirect URIs registered at each external provider.
