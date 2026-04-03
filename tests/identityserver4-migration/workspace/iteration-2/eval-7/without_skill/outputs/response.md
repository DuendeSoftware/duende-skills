# Persisted Grants Decryption Issue After .NET Upgrade

This is likely a Data Protection issue. ASP.NET Core uses Data Protection to encrypt sensitive data, and when you upgrade .NET versions, the keys or configuration may change.

## Possible Causes

1. **Data Protection keys rotated or lost** — If your Data Protection keys were stored in memory (default), they're lost on restart
2. **Key ring location changed** — The default location may differ between .NET versions
3. **Application discriminator changed** — If the app name or path changed, it might use different keys

## Fix

Try setting an explicit application name in Data Protection:

```csharp
builder.Services.AddDataProtection()
    .SetApplicationName("YourApp");
```

Also ensure your old Data Protection keys are still accessible (not deleted or rotated away).

If the keys are truly lost, you may need to clear the old persisted grants and have users re-authenticate.
