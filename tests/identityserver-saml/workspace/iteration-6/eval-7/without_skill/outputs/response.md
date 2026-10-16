# Requirements for SAML support

- **Package**: As far as I know, SAML IdP support is part of the main `Duende.IdentityServer` package (new in v8), so no separate package should be needed — there may be an optional additional package for specific stores, so check the release notes.
- **License**: It's a premium feature; I believe it requires the **Enterprise** edition (Starter/Business probably don't include it). Confirm with Duende.
- **.NET**: IdentityServer 8 targets .NET 10 (your csproj uses net10.0), so you need the .NET 10 SDK/runtime.

Enable with `.AddSaml()` and register service providers.
