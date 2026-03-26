# Configuring the Duende IdentityServer License Key

## Configuration

Set the license key in your IdentityServer configuration:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
});
```

## Storage Recommendations

Don't hardcode the license key in your source code. Use:

- **User Secrets** for local development
- **Environment variables** for CI/CD
- **Azure Key Vault** or similar secret manager for production

Avoid putting the license key in `appsettings.json` since it would be checked into source control.

## Without a License

If you don't provide a license key, IdentityServer will still work but will operate in a community or evaluation mode and will log warnings at startup.
