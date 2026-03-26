# Fixing "Response Has Expired" SAML Errors

The "response has expired" error from SAML service providers is commonly caused by clock skew between your IdentityServer (IdP) and the service provider. Even if your server's clock is synchronized, the SP's clock tolerance may be tighter than expected.

## The Fix: Increase DefaultClockSkew

The relevant setting is `DefaultClockSkew` in `IdentityServerOptions.Saml`. The default is **5 minutes**, which works for most SPs, but some environments need more tolerance:

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Increase clock skew tolerance for SAML assertions
    // Default is 5 minutes — increase if SPs report expired responses
    options.Saml.DefaultClockSkew = TimeSpan.FromMinutes(10);
})
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

## What This Controls

`DefaultClockSkew` adds a tolerance window to the validity period of SAML assertions. If set to 10 minutes, an assertion timestamped at 12:00 would be considered valid by the SP from 11:50 to 12:10 (assuming the SP respects the skew).

## Other Useful Settings

If you're also seeing "request too old" errors, you can increase the maximum age of incoming AuthnRequests:

```csharp
options.Saml.DefaultRequestMaxAge = TimeSpan.FromMinutes(15);
```

## Recommendations

1. Start by increasing `DefaultClockSkew` to 10 minutes
2. If that doesn't resolve it, check the SP's own clock skew tolerance
3. If the SP allows configuration, have them increase their tolerance as well
4. Monitor with structured logging — IdentityServer logs SAML assertion timestamps
5. As a last resort, verify NTP synchronization on both sides