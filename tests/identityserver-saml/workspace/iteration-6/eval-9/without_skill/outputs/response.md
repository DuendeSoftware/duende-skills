# Accepting unsolicited SAML responses in IdentityServer as an SP

I'm not certain of the exact option names in Duende's built-in SAML SP handler; the pattern is as follows (approximate):

```csharp
builder.Services.AddAuthentication()
    .AddSaml2("corp-idp", options =>
    {
        options.SPOptions.EntityId = new EntityId("https://login.example.com/saml-sp");
        options.IdentityProviders.Add(new IdentityProvider(
            new EntityId("https://idp.corp.com"), options.SPOptions)
        {
            MetadataLocation = "https://idp.corp.com/metadata",
            AllowUnsolicitedAuthnResponse = true
        });
    });
```

Handling the callback safely:
- Only allow unsolicited responses from a specific, trusted IdP; require **signed** assertions/responses and validate against the IdP's metadata certificate.
- Validate Audience, Destination, NotBefore/NotOnOrAfter, and Issuer.
- **Replay protection**: store assertion IDs (distributed cache) until expiry.
- No InResponseTo exists, so no CSRF binding: validate `RelayState` against an allow-list of local return URLs (open-redirect risk) and never trust it blindly.
- Don't auto-provision accounts without mapping/verification; use the external login callback to map to a local user, then `SignInAsync` with the IdentityServer cookie scheme.
- Keep clock skew small and log failures.
