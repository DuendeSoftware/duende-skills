# Consuming Unsolicited (IdP-Initiated) AuthnResponses as a SAML SP

When IdentityServer acts as a **SAML Service Provider** (federating from a corporate IdP), use the built-in Duende SAML SP handler, `AddSamlServiceProvider`, registered on the **`AddAuthentication()`** builder as an external scheme that feeds IdentityServer's external cookie. To accept **IdP-initiated (unsolicited)** `AuthnResponse` messages, you opt in with `AllowUnsolicitedAuthnResponse` and — importantly — you **must** also set `IdpInitiatedCallbackUrl`.

## Registration

```csharp
using Duende.IdentityServer;

builder.Services.AddAuthentication()
    .AddSamlServiceProvider("corporate-idp", options =>
    {
        options.SpEntityId = "https://sp.example.com";
        options.IdpEntityId = "https://idp.example.com";
        options.SingleSignOnServiceUrl = "https://idp.example.com/sso";

        // List → supports IdP signing-cert rollover
        options.SigningCertificatesBase64 = ["<base64-idp-cert>"];

        // Feed the IdentityServer external cookie
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;

        // --- IdP-initiated (unsolicited) SSO opt-in ---
        options.AllowUnsolicitedAuthnResponse = true;                // default: false
        options.IdpInitiatedCallbackUrl = "/ExternalLogin/Callback"; // REQUIRED when the above is true
    });
```

Key points:

- **`AddSamlServiceProvider` on `AddAuthentication()`** registers the native Duende SAML SP handler as an external scheme.
- **`AllowUnsolicitedAuthnResponse = true`** enables acceptance of unsolicited (IdP-initiated) responses. It defaults to `false`.
- **`IdpInitiatedCallbackUrl` is required** whenever unsolicited responses are allowed. It's the redirect target after the unsolicited response is processed — a relative path (`/ExternalLogin/Callback`) or an absolute http/https URL.
- **`SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme`** ensures the authenticated result lands in IdentityServer's external cookie, so the login UI can complete the local sign-in.

## Handling the callback safely

Your callback authenticates against the **external cookie scheme** and reads the IdP-supplied RelayState from `AuthenticationProperties.Items["relayState"]`:

```csharp
public async Task<IActionResult> Callback()
{
    // Authenticate against the IdentityServer external cookie
    var result = await HttpContext.AuthenticateAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);

    if (!result.Succeeded)
        return BadRequest();

    // IdP-supplied RelayState (only present when ≤ MaxRelayStateLength).
    // "scheme" and "returnUrl" items are also populated.
    var relayState = result.Properties.Items.TryGetValue("relayState", out var rs)
        ? rs
        : null;

    // ⚠️ SECURITY: RelayState is UNTRUSTED input from the IdP flow.
    // NEVER redirect to it directly. Validate it against an allow-list
    // of known-safe local targets before using it as a redirect.
    var redirectTarget = "/";
    if (!string.IsNullOrEmpty(relayState) && IsSafeLocalRedirect(relayState))
        redirectTarget = relayState;

    // ... issue the local IdentityServer session from result.Principal ...

    return Redirect(redirectTarget);
}

private bool IsSafeLocalRedirect(string target)
    // Only allow local, relative URLs you recognize — reject absolute/off-host URLs.
    => Url.IsLocalUrl(target) && AllowedTargets.Contains(target);
```

## Security warning

> ⚠️ IdP-initiated (unsolicited) SSO is inherently exposed to **CSRF** — there is no SAML-compliant way to eliminate that risk. Only enable `AllowUnsolicitedAuthnResponse` after a security review.

Equally important: **treat `RelayState` as untrusted input.** Because it originates from the IdP-initiated flow and can be attacker-influenced, never use it as a redirect target without validating it (e.g., `Url.IsLocalUrl` plus an allow-list). Note also that oversized RelayState (> `MaxRelayStateLength`, default 1024) is **silently dropped**, so your callback must tolerate its absence.
