# Configuring the Duende IdentityServer License Key

## How to Configure

The license key is set via `IdentityServerOptions.LicenseKey` in your `AddIdentityServer()` call:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
});
```

## Where to Store the License Key

**Never store the license key in source-controlled files** like `appsettings.json` or `appsettings.Development.json`. Instead, use one of these approaches:

### User Secrets (Development)
```bash
dotnet user-secrets set "IdentityServer:LicenseKey" "your-license-key-here"
```

### Environment Variables (CI/CD, Containers)
```bash
export IdentityServer__LicenseKey="your-license-key-here"
```

### Azure Key Vault (Production)
```csharp
builder.Configuration.AddAzureKeyVault(
    new Uri("https://your-vault.vault.azure.net/"),
    new DefaultAzureCredential());
```

### AWS Secrets Manager, HashiCorp Vault, etc.
Any secret management system that integrates with .NET's `IConfiguration` system works.

## What Happens Without a License Key

Without a license key, Duende IdentityServer runs in **community/trial mode**:
- It logs a **warning on startup** indicating that no license key is configured
- All features remain functional during the trial period
- This mode is acceptable for local development and evaluation
- **Production deployments require a valid license key**

## Choosing the Right Edition

The license edition depends on your client inventory:
- **Count interactive clients** (those using `authorization_code` grant — web apps, SPAs, native apps)
- **Count non-interactive clients** (those using `client_credentials` — machine-to-machine)

Run the Migration Analysis Tool against your running IdentityServer4 instance to get these counts automatically. See [Duende IdentityServer Pricing](https://duendesoftware.com/products/identityserver) for edition thresholds.
