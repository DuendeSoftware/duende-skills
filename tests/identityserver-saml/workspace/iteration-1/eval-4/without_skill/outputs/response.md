# Fixing "Response Has Expired" SAML Errors

This is a common issue in SAML integrations and is usually related to time synchronization between systems.

## Check Token Lifetime

The SAML assertion may have too short a lifetime. You can increase the token lifetime in your IdentityServer configuration:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = true;
});
```

## Verify Clock Synchronization

Even if your server's clock seems fine, make sure:

1. NTP is properly configured on your IdentityServer host
2. The time zone settings are correct
3. The SP's server clock is also synchronized

## Increase Token Validity

If using SAML assertions, you might need to adjust the assertion lifetime or add tolerance:

```csharp
// If your SAML library supports it, increase assertion validity
builder.Services.Configure<SamlOptions>(options =>
{
    options.AssertionLifetime = TimeSpan.FromMinutes(30);
    options.AllowedClockSkew = TimeSpan.FromMinutes(10);
});
```

## Other Considerations

- Check if there's a proxy or load balancer that's adding latency
- Verify the assertion `NotBefore` and `NotOnOrAfter` conditions
- Some SPs have their own clock skew settings — check their documentation
- Consider using NTP monitoring to alert on clock drift