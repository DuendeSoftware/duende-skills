# Will your external authentication providers still work after migrating to Duende?

Short answer: **yes, they can — but each authentication handler is a separate NuGet package that must be updated to a version compatible with your new target framework (.NET 8+ / ASP.NET Core 8+).** Duende IdentityServer doesn't replace these handlers; they plug into ASP.NET Core's authentication system, so what really matters is that each handler package matches the .NET version you upgrade to.

## Per-provider guidance

**Google OAuth (`Microsoft.AspNetCore.Authentication.Google`)**
Update this package to the version matching your target framework (e.g. the `8.0.x` line for .NET 8). The `AddGoogle(...)` registration API is stable, so it's typically just a version bump.

**WS-Federation for Azure AD (`Microsoft.AspNetCore.Authentication.WsFederation`)**
This handler **needs its NuGet package updated** to the matching .NET version. It's a Microsoft package, so a version bump to `8.0.x` is usually all that's required; re-verify your `MetadataAddress`, `Wtrealm`, and token-validation settings after upgrading.

**Custom SAML2P via Sustainsys.Saml2**
Update **Sustainsys.Saml2** to a release **compatible with .NET 8+/ASP.NET Core 8+**. Third-party SAML libraries track ASP.NET Core versions, so pin a version that explicitly supports your target framework. Check its changelog for any breaking configuration changes between the version you're on and the compatible one.
(Note: Duende IdentityServer v8 also has **built-in SAML 2.0 IdP support**, so depending on your scenario you might eventually consolidate onto that instead of a separate handler — but that's optional and separate from the migration.)

## Don't skip end-to-end testing

Package compatibility isn't enough on its own — **test every external login flow end-to-end after migration**:

- Google sign-in round-trip
- WS-Federation sign-in against Azure AD (and sign-out if used)
- SAML2P login and logout via Sustainsys.Saml2

Incompatible or mis-updated handlers typically fail **at runtime** when a user actually attempts to authenticate (assembly load errors, callback/scheme errors), not at build time — so verify each scheme actually completes a login before you consider the migration done.

## Summary

- Every third-party auth handler needs a **NuGet package update** to match .NET 8+.
- **WS-Federation** handler: update the package.
- **SAML2P (Sustainsys.Saml2)**: update to a .NET 8+-compatible version.
- **Google**: version bump.
- **Test all external login flows end-to-end** after the upgrade.
