# External Authentication Providers After Migration

Your third-party authentication handlers should generally work after migration, but you'll need to update their NuGet packages to be compatible with the new .NET version.

## Google OAuth
Should work fine — just update the `Microsoft.AspNetCore.Authentication.Google` package to match your target framework.

## WS-Federation
Update `Microsoft.AspNetCore.Authentication.WsFederation` to the .NET 8 compatible version. The APIs should be mostly the same.

## Sustainsys.Saml2 (SAML2P)
Check if there's a version of Sustainsys.Saml2 compatible with .NET 8. This might require more changes since SAML libraries sometimes have breaking changes between major versions.

## General Advice
After migration, make sure to test all your external login flows to ensure they still work correctly. Pay attention to any changes in claim mapping or callback handling.
