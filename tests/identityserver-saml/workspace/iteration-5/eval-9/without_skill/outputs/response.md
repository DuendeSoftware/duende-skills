# Accepting IdP-Initiated (Unsolicited) SAML SSO

When your application acts as a SAML **Service Provider** and the corporate IdP performs IdP-initiated SSO, the IdP sends an unsolicited `AuthnResponse` (a SAML assertion) to your ACS endpoint without your app having first sent an `AuthnRequest`. You need to (a) allow unsolicited responses and (b) handle the resulting sign-in and redirect carefully.

## Configuring the SAML SP handler

Using a SAML authentication handler (for example `Sustainsys.Saml2`, a common choice for ASP.NET Core SPs), register it as an external authentication scheme and enable unsolicited responses:

```csharp
builder.Services.AddAuthentication()
    .AddSaml2("saml", options =>
    {
        options.SPOptions.EntityId = new EntityId("https://sp.example.com");
        options.SignInScheme = "External"; // external cookie scheme

        var idp = new IdentityProvider(
            new EntityId("https://idp.example.com"), options.SPOptions)
        {
            SingleSignOnServiceUrl = new Uri("https://idp.example.com/sso"),
            Binding = Saml2BindingType.HttpRedirect,
            AllowUnsolicitedAuthnResponse = true // accept IdP-initiated SSO
        };
        idp.SigningKeys.AddConfiguredKey(idpCertificate);
        options.IdentityProviders.Add(idp);
    });
```

The important flag is `AllowUnsolicitedAuthnResponse = true`, which tells the handler to accept assertions that weren't preceded by a request from your SP.

## Handling the callback and RelayState

With IdP-initiated flows, the IdP may include a `RelayState` value indicating where the user should land after login. Your callback should:

1. Complete authentication against the external cookie scheme.
2. Read the RelayState.
3. **Validate** RelayState before redirecting.

```csharp
var result = await HttpContext.AuthenticateAsync("External");
var relayState = result.Properties.Items.TryGetValue("RelayState", out var rs) ? rs : null;

// SECURITY: RelayState comes from outside and can be attacker-controlled.
// Never redirect to it blindly — validate against known-safe local targets.
var target = (relayState is not null && Url.IsLocalUrl(relayState)) ? relayState : "/";
return Redirect(target);
```

## Security considerations

- **CSRF / replay**: IdP-initiated SSO has no in-flight request to correlate against, so it's more exposed to CSRF and assertion replay. Ensure assertions are signed, enforce `NotOnOrAfter`/`OneTimeUse` conditions, and keep clock skew tight.
- **Untrusted RelayState**: Treat RelayState strictly as untrusted input; only use it as a redirect target after validating it's a local, allow-listed URL.
- **Signature validation**: Verify the assertion signature against the IdP's certificate.

## Recommendation

The exact option names differ by handler. If you're using Duende IdentityServer's own SAML SP support or a specific plugin, check its documentation for the equivalent of `AllowUnsolicitedAuthnResponse` and how it surfaces RelayState in the callback.
