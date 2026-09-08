# SAML with Duende IdentityServer: Package, License, and .NET Version

## Do I need a separate NuGet package?

Historically, SAML 2.0 support has **not** been part of the core IdentityServer package and required a separate add-on. In the IdentityServer4 era and early Duende versions, the common route was a third-party SAML plugin such as **Rock Solid Knowledge's `Rsk.Saml`** package, installed alongside `Duende.IdentityServer`. So in most existing setups you'd add an extra package to get SAML.

That said, Duende has been expanding first-party protocol support, so if you're on a recent major version, check whether SAML is now available directly in the `Duende.IdentityServer` package before pulling in a third-party plugin.

## What license edition is required?

SAML is a premium capability. It requires one of Duende's **higher/paid editions** (such as Enterprise/Business-tier or the equivalent add-on), not the free/community usage. The exact edition name and whether it's an add-on vs. included depends on your Duende licensing agreement — confirm with Duende's pricing/licensing page.

## Which .NET version?

Duende IdentityServer targets modern .NET. Recent major versions require a current .NET runtime — typically **.NET 6/8 or later** depending on the IdentityServer version you pick. Match your `TargetFramework` to what your chosen `Duende.IdentityServer` version supports.

## Recommendation

- Confirm the exact SAML package (first-party vs. `Rsk.Saml` or similar) for your specific IdentityServer version.
- Verify the required license edition with Duende directly, since SAML is a paid feature.
- Use a currently supported .NET LTS release.
