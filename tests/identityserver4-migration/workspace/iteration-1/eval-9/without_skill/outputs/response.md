# Configuring Duende IdentityServer License Key

## Configuration

Duende IdentityServer is a commercial product and requires a license for production use. You can configure it in your service registration:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
});
```

## Storage Recommendations

For security, you should load the license key from a secure configuration source rather than hardcoding it:

- **Environment variables**: Set `IdentityServer__LicenseKey` as an environment variable
- **User Secrets**: Use `dotnet user-secrets` for local development
- **Azure Key Vault** or similar secret management service for production

Avoid committing the license key to source control. Don't put it directly in `appsettings.json` if that file is checked into your repository.

## Without a License Key

If you don't provide a license key, Duende IdentityServer will still run but in a limited or evaluation capacity. You'll likely see warnings in the logs indicating that no license has been configured. For production deployments, you should purchase and configure the appropriate license from Duende Software.

## Pricing

Duende offers different license tiers based on your needs — check [duendesoftware.com](https://duendesoftware.com) for current pricing and edition details.
