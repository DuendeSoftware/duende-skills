# Fixing SAML "Response Has Expired" Errors

When a SAML service provider reports "response has expired" errors, it's usually due to clock skew between the Identity Provider and the Service Provider. Here are the settings to look at:

## Token Lifetime Settings

You can adjust the token lifetime and validity window:

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Increase the allowed clock skew for token validation
    options.Authentication.CookieLifetime = TimeSpan.FromHours(10);
})
    .AddSaml();
```

## SAML Response Validity

Check your SAML response configuration:

```csharp
builder.Services.Configure<Saml2Options>(options =>
{
    options.MaxClockSkew = TimeSpan.FromMinutes(10);
    options.TokenLifetime = TimeSpan.FromMinutes(15);
});
```

## Recommendations

1. **Increase the clock skew tolerance** from the default (usually 5 minutes) to something larger like 10 minutes
2. **Check NTP**: Ensure both the IdP and SP have synchronized clocks
3. **Review response validity**: Make sure the response `NotOnOrAfter` conditions allow enough time
4. **Network latency**: Factor in network transit time between the IdP and SP

## On the SP Side

Ask the SP administrator to check their clock skew tolerance settings as well. Most SAML libraries have a configurable maximum clock skew.
