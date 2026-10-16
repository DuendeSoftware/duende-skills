**Probably yes, but you need to update the packages.** External providers are ASP.NET Core authentication handlers, so they keep working as long as they're compatible with the new target framework (v7 → .NET 8, v8 → .NET 10). Handlers compiled against older ASP.NET Core versions can fail at runtime.

| Provider | Action |
|---|---|
| **Google OAuth** | Update `Microsoft.AspNetCore.Authentication.Google` to the version matching your target framework. |
| **WS-Federation (Azure AD)** | Update `Microsoft.AspNetCore.Authentication.WsFederation` to match the target .NET version. |
| **Sustainsys.Saml2** | Update to a version compatible with your target .NET. Note Duende IdentityServer **v8 has built-in SAML 2.0 IdP support** (see the `identityserver-saml` skill) — that's for acting as an IdP, while Sustainsys is for consuming an external SAML IdP. |
| Custom `IAuthenticationHandler` | `AuthenticateAsync`/`ChallengeAsync`/`ForbidAsync` are stable, but check constructor-injected types. |

Also:
- Update namespaces (`IdentityServerConstants` etc. → `Duende.IdentityServer`).
- The Migration Analysis Tool lists registered authentication schemes and flags non-Microsoft handlers.
- Keep issuer URI and public host stable so callback/redirect URIs registered with providers stay valid; behind a proxy configure forwarded headers.
- After migrating, test every external login flow end to end.
