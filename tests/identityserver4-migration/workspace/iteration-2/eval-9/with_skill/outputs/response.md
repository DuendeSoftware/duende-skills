# Configuring the Duende IdentityServer License Key

## Where to Configure

Set the license key via `IdentityServerOptions.LicenseKey` inside `AddIdentityServer`:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
});
```

## Where to Store It

**Never store the license key in source-controlled files like `appsettings.json`.** Instead, use one of:

- **User Secrets** (development): `dotnet user-secrets set "IdentityServer:LicenseKey" "your-key"`
- **Environment variables**: `IdentityServer__LicenseKey=your-key`
- **Azure Key Vault** or other secret manager
- **CI/CD pipeline secrets** injected at deployment time

Example with environment variables:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
    // Reads from appsettings.json, environment variables, user secrets, etc.
    // via the standard ASP.NET Core configuration system
});
```

## What Happens Without a License Key

Without a license key, IdentityServer runs in **community/trial mode** and logs a warning on startup. This is acceptable for:
- Local development
- Testing environments
- Evaluation

For production deployments, a valid license key is required.

## License Editions

The edition you need depends on your client inventory — count interactive clients (authorization_code) vs. non-interactive clients (client_credentials). Run the Migration Analysis Tool before migrating to get these counts.
