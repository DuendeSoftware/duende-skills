# Fixing Clock Skew Issues

If you're seeing "response has expired" errors, you may need to increase the clock skew tolerance.

In your IdentityServer or token validation configuration, look for a clock skew setting:

```csharp
// If using JWT bearer:
options.TokenValidationParameters.ClockSkew = TimeSpan.FromMinutes(10);

// Or in IdentityServer options:
builder.Services.AddIdentityServer(options =>
{
    // There may be a global clock skew setting
    // Check the documentation for the specific setting name
});
```

The default clock skew in most .NET authentication handlers is 5 minutes. You could increase it to 10 or 15 minutes to accommodate clock drift between servers.

Also ensure NTP is properly configured on both the IdP and SP sides.
