Mostly yes, since external providers are ASP.NET Core authentication handlers, not IdentityServer-specific.

- **Google OAuth**: `AddGoogle` (Microsoft.AspNetCore.Authentication.Google) works; upgrade the package to the net8 version. Keep the same callback path (`/signin-google`) and sign-in scheme: `options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme` (now `Duende.IdentityServer.IdentityServerConstants`).
- **WS-Federation**: `Microsoft.AspNetCore.Authentication.WsFederation` supports modern .NET; update the package and test, as the underlying token handlers changed (Microsoft.IdentityModel/ JsonWebToken handler). Same SignInScheme caveat.
- **Sustainsys.Saml2**: use `Sustainsys.Saml2.AspNetCore2` version that targets your new framework; it works with Duende but check for maintenance status and compatibility.

General:
- Update namespaces `IdentityServer4` → `Duende.IdentityServer` in code using `IdentityServerConstants`.
- Your callback endpoints and redirect URIs registered with providers must remain the same, so keep the public host/issuer stable.
- Behind a proxy, forwarded headers matter for redirect URI generation.
- Test claims mapping (`JwtSecurityTokenHandler.DefaultMapInboundClaims`) after the framework upgrade.
- Duende has SAML2P-ready options through the Sustainsys integration or Duende's own offerings (no built-in SAML IdP).
