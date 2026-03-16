# External Authentication Providers After Migrating to Duende IdentityServer

Your external authentication providers should generally continue to work after migration, but they will need some attention since you're also upgrading the .NET framework version.

## Google OAuth

Google authentication via `Microsoft.AspNetCore.Authentication.Google` should work fine. When targeting .NET 8, the authentication packages are updated as part of the framework. The configuration API is the same, so your `AddGoogle()` setup should work without changes.

## WS-Federation for Azure AD

The WS-Federation handler (`Microsoft.AspNetCore.Authentication.WsFederation`) will need its NuGet package updated to match your new .NET version. Make sure to install the version that matches your target framework:

```xml
<PackageReference Include="Microsoft.AspNetCore.Authentication.WsFederation" Version="8.0.0" />
```

The configuration API remains similar, so your existing setup should work after the package update.

## Sustainsys.Saml2

The SAML2P handler from Sustainsys will need a version compatible with .NET 8. Check the Sustainsys.Saml2 GitHub repository for a version that supports your target framework. There may be breaking changes in newer major versions of the library.

## General Recommendations

- Update all authentication-related NuGet packages to versions compatible with your target framework
- Test each external login flow after migration to verify they work correctly
- Check for any breaking changes in the authentication handler APIs between framework versions
- Review any custom `IAuthenticationHandler` implementations for compatibility
