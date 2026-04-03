# Duende IdentityServer License Key Configuration

## Configuration

You can configure the license key in your startup:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
});
```

## Storage

Store the license key securely — don't check it into source control. Use environment variables, Azure Key Vault, or user secrets for development.

## Without a License

Duende IdentityServer has different licensing tiers. If you don't provide a license key, the server will still run but may have limitations or show warnings.

Check the Duende website for current licensing terms and pricing.
