# Accepting IdP-initiated (unsolicited) responses in the SAML SP handler

```csharp
builder.Services.AddAuthentication()
    .AddSamlServiceProvider("corporate-idp", options =>
    {
        options.SpEntityId = "https://sp.example.com";
        options.IdpEntityId = "https://idp.corp.com";
        options.SingleSignOnServiceUrl = "https://idp.corp.com/sso";
        options.SigningCertificatesBase64 = ["<current-base64>", "<next-base64>"]; // list → cert rollover
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;

        options.AllowUnsolicitedAuthnResponse = true;                  // default false
        options.IdpInitiatedCallbackUrl = "/ExternalLogin/Callback";   // REQUIRED when the above is true
    });
```

`MaxRelayStateLength` defaults to 1024 bytes; larger RelayState is **silently dropped**.

(For dynamic providers, `SamlProvider` has the same two properties, but uses `SigningCertificateBase64` — singular string.)

## Safe callback

```csharp
public async Task<IActionResult> OnGet()
{
    var result = await HttpContext.AuthenticateAsync(
        IdentityServerConstants.ExternalCookieAuthenticationScheme);
    if (result?.Succeeded != true) throw new InvalidOperationException("External auth failed");

    result.Properties!.Items.TryGetValue("relayState", out var relayState);
    // Items also hold "scheme" and "returnUrl"

    // RelayState is UNTRUSTED: validate before redirecting
    var returnUrl = "~/";
    if (!string.IsNullOrEmpty(relayState) && Url.IsLocalUrl(relayState))
        returnUrl = relayState;               // or check against an explicit allow-list

    // ...map/provision local user from result.Principal, sign in locally,
    // delete the external cookie, then:
    return LocalRedirect(returnUrl);
}
```

## Security notes
- Unsolicited responses have no `InResponseTo`, so there's no request correlation — this is inherently CSRF-exposed in SAML. Enable it only after review; prefer the alternative where the IdP links to an SP-initiated login endpoint (like OIDC third-party-initiated login).
- Pin the IdP signing certs, only enable on the one scheme that needs it.
- Never use RelayState as an open redirect target; also note it may be missing if oversized.
- Map the external identity carefully (don't auto-link on email alone).
