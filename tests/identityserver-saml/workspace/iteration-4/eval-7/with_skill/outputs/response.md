# Adding SAML Support to Duende IdentityServer: Package, License, and .NET Requirements

## Short Answers

| Question | Answer |
|---|---|
| Separate NuGet package? | **No** — SAML 2.0 IdP support is built into `Duende.IdentityServer` (v8.0+) |
| License edition required? | **Standard (add-on), Advanced, or Custom Edition** |
| .NET version? | **.NET 8 or later** (IdentityServer v8.0+ requirement) |

---

## NuGet Package

SAML 2.0 IdP functionality ships **inside** the core `Duende.IdentityServer` NuGet package — there is no separate `Duende.IdentityServer.Saml` package to install. You simply call `.AddSaml()` in your builder chain once your license covers it.

```xml
<!-- Your existing package reference — no additional package needed -->
<PackageReference Include="Duende.IdentityServer" Version="8.*" />
```

> **Note on SP mode (consuming SAML from external IdPs):** If you want IdentityServer to act as a *SAML Service Provider* (federating with an external SAML IdP), that requires a third-party authentication handler such as `Sustainsys.Saml2` or `ITfoxtec.Identity.Saml2`. Those are separate packages. The built-in SAML support covers **IdP mode only** (IdentityServer issuing SAML assertions to service providers).

---

## License Edition

SAML requires one of:

- **Standard Edition with the SAML add-on**
- **Advanced Edition** (includes SAML)
- **Custom Edition** (includes SAML)

The Community Edition (free tier) does **not** include SAML. If you call `.AddSaml()` without a qualifying license, IdentityServer will throw a `LicenseValidationException` at startup with a message indicating the feature is not available for your edition.

Check your current license edition in the [Duende Software portal](https://portal.duendesoftware.com).

---

## .NET Version

Duende IdentityServer v8.0 (which introduced the built-in SAML IdP) targets **.NET 8** and later. You need:

- .NET 8.0+ runtime and SDK
- ASP.NET Core 8.0+ (included with .NET 8)

---

## Minimal Setup

Once you have the license, enabling SAML IdP support is a two-line change to your `Program.cs`:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddSaml()                                            // <-- enable SAML IdP
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders); // <-- register SPs
```

The `.AddSaml()` call registers the SAML endpoints and middleware. The `.AddInMemorySamlServiceProviders(...)` call registers your service providers (in-memory is fine for development; use EF Core or a custom store in production).

---

## What `.AddSaml()` Gives You

After adding SAML, the following endpoints are automatically available:

| Endpoint | Path | Purpose |
|---|---|---|
| Metadata | `/Saml2` | IdP metadata document (certificates, endpoints, NameID formats) |
| SSO | `/Saml2/SSO` | Receives AuthnRequests (HTTP-GET and HTTP-POST) |
| SSO Callback | `/Saml2/SSO/Callback` | Builds and sends SAML Response after authentication |
| SLO | `/Saml2/SLO` | Handles LogoutRequest / LogoutResponse |
| SLO Callback | `/Saml2/SLO/Callback` | Completes SLO round-trip |

---

## One Additional Requirement: Update Your Login Page

SAML flows have a cancellation mechanism. If the user clicks "Cancel" on your login page during a SAML-initiated flow, you must call `DenyAuthenticationAsync` so IdentityServer can send a proper SAML error response back to the SP. Without this, the user is left stuck with no redirect.

```csharp
// In your Login Razor Page or controller, on "cancel" action:
var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
if (context != null)
{
    await _interaction.DenyAuthenticationAsync(context, new AuthorizationDeniedContext
    {
        Error = AuthorizationError.AccessDenied
    });
    return Redirect(returnUrl);
}
```

This works because `IIdentityServerInteractionService.GetAuthorizationContextAsync` can return a `SamlAuthenticationContext` for SAML flows (pattern-matchable), giving you full access to the SP's details if needed.

---

## Summary

1. **No extra NuGet package** — `Duende.IdentityServer` v8.0+ contains it all.
2. **License** — Standard (SAML add-on), Advanced, or Custom Edition required.
3. **.NET 8+** — required by IdentityServer v8.0.
4. **Two-line setup** — `.AddSaml()` + `.AddInMemorySamlServiceProviders(...)`.
5. **Update login page** — call `DenyAuthenticationAsync` for cancellation support.
