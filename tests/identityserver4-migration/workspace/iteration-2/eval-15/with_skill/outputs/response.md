# External Authentication Provider Compatibility

Your existing authentication handlers will need NuGet package updates when upgrading to .NET 8+ with Duende IdentityServer. Here's what to do for each:

## Google OAuth (`Microsoft.AspNetCore.Authentication.Google`)

Update the NuGet package to match your target framework version:
```xml
<!-- For net8.0 -->
<PackageReference Include="Microsoft.AspNetCore.Authentication.Google" Version="8.0.0" />
```
This is a Microsoft-maintained package and will have a matching version for each .NET release.

## WS-Federation (`Microsoft.AspNetCore.Authentication.WsFederation`)

Update the NuGet package to match the target .NET version:
```xml
<!-- For net8.0 -->
<PackageReference Include="Microsoft.AspNetCore.Authentication.WsFederation" Version="8.0.0" />
```
Check for any API changes in the handler configuration between versions.

## SAML2P (Sustainsys.Saml2)

Sustainsys.Saml2 needs a version compatible with .NET 8+. Check the [Sustainsys.Saml2 releases](https://github.com/Sustainsys/Saml2) for the latest compatible version:
```xml
<PackageReference Include="Sustainsys.Saml2.AspNetCore2" Version="2.x.x" />
```
Sustainsys may have breaking API changes between major versions — review their migration notes.

## After Migration

**Test all external login flows end-to-end after migration.** Missing or incompatible handlers will cause runtime errors when users attempt to authenticate via those schemes. Specifically test:
1. Initiating login via each external provider
2. Receiving the callback and creating/matching the local user
3. Token issuance after external authentication
4. Sign-out flows that involve external providers

The Migration Analysis Tool (Step 0) lists all registered authentication schemes and flags non-Microsoft, non-IdentityServer4 handlers that may need attention.
