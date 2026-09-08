# Will Google, WS-Federation, and SAML2P still work after moving to Duende?

Yes, they can all continue to work — the move to Duende IdentityServer itself doesn't remove or replace your external authentication handlers, because those are standard ASP.NET Core authentication handlers that sit alongside IdentityServer. The real work is that the migration comes with a **.NET version upgrade**, and **each third-party authentication handler is a NuGet package that has to be updated to a version compatible with the new target framework** (.NET 8+ / ASP.NET Core 8+).

## Going through your three providers

- **Google OAuth (`Microsoft.AspNetCore.Authentication.Google`)** — bump this package to the version that matches your new framework (the `8.0.x` line for .NET 8). The `AddGoogle()` API hasn't meaningfully changed, so this is usually a straight version update.

- **WS-Federation for Azure AD (`Microsoft.AspNetCore.Authentication.WsFederation`)** — this handler **needs to be updated** to the matching .NET 8+ version. It's a Microsoft-maintained package, so it's mostly a version bump, but recheck your realm/metadata configuration afterward.

- **Custom SAML2P with Sustainsys.Saml2** — update **Sustainsys.Saml2** to a release that **explicitly supports .NET 8+/ASP.NET Core 8+**. Community/third-party SAML libraries are tied fairly tightly to the ASP.NET Core version, so make sure you pick a compatible major version and read its release notes for any breaking changes in configuration or APIs.

## Test everything before you call it done

Auth handler incompatibilities usually don't show up at compile time — they surface **at runtime** when a user tries to log in through that scheme. So after the upgrade, **run each external login flow end-to-end**: sign in with Google, sign in via WS-Federation against Azure AD, and complete a SAML2P login (and logout) through Sustainsys.Saml2. Only once each provider completes a full round-trip should you consider the external auth part of the migration finished.

In short: expect a package update for each handler to match the new .NET version, pay particular attention to the WS-Federation and Sustainsys.Saml2 packages since those are the ones most likely to need a deliberate compatible version, and validate every external login path after migrating.
