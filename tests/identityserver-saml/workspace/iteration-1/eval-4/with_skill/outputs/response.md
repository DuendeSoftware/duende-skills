# Fixing "Response Has Expired" SAML Errors

The "response has expired" error is typically caused by clock skew between your IdentityServer and the SAML service provider. The relevant setting is **`DefaultClockSkew`** in the SAML options.

## Configuration

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Increase SAML clock skew tolerance
    // Default is 5 minutes — increase if SPs report expiration errors
    options.Saml.DefaultClockSkew = TimeSpan.FromMinutes(10);
    
    // You may also want to increase the maximum age for authentication requests
    options.Saml.DefaultRequestMaxAge = TimeSpan.FromMinutes(15);
})
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

## What `DefaultClockSkew` Does

The `DefaultClockSkew` setting (configured via `options.Saml.DefaultClockSkew`) controls the tolerance window for time-based validation in SAML responses. The default is **5 minutes**. When an SP validates a SAML response, it checks timestamps like `NotBefore` and `NotOnOrAfter`. If the clock difference between your IdP and the SP exceeds the allowed skew, the response is rejected as expired.

## Recommendations

1. **Start by increasing to 10 minutes**: `options.Saml.DefaultClockSkew = TimeSpan.FromMinutes(10)` — this handles most real-world clock drift scenarios.

2. **Investigate the root cause**: While increasing clock skew is a valid workaround, consider:
   - Ensure both servers use NTP for time synchronization
   - Check if the SP has its own clock skew setting that can be adjusted

3. **Don't set it too high**: Excessively large clock skew windows reduce security by allowing replay of older responses.

4. **This is SAML-specific**: The `options.Saml.DefaultClockSkew` setting only affects SAML response validation. It does not impact OIDC or OAuth token lifetimes.
