# Fixing "Response Has Expired" Errors in SAML

The "response has expired" error typically means the SAML assertion's validity window has passed by the time the SP validates it. Even if clocks are synced on your end, the SP's clock may be slightly off, or network latency can push the validation outside the window.

## Increase DefaultClockSkew

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Increase SAML clock skew tolerance (default is 5 minutes)
    options.Saml.DefaultClockSkew = TimeSpan.FromMinutes(10);
})
    .AddSaml()
    .AddInMemorySamlServiceProviders(Config.SamlServiceProviders);
```

## Key Points

- **`options.Saml.DefaultClockSkew`** controls how much time drift is tolerated when validating SAML assertions. The default is 5 minutes.
- Increase this value if you see "response has expired" or "response is not yet valid" errors — try 10 or 15 minutes.
- You can also check `options.Saml.DefaultRequestMaxAge` which controls how long an `AuthnRequest` remains valid.
- This is a **SAML-specific** setting under `options.Saml` — it does not affect OIDC/OAuth token validation.
