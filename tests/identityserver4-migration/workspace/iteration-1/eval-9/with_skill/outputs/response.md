# Configuring the Duende IdentityServer License Key

## How to Configure

Configure the license key via `options.LicenseKey` inside the `AddIdentityServer` call:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
});
```

## Where to Store the License Key

Load the license key from a secure source — **never store it in source-controlled files** like `appsettings.json`. Recommended approaches:

1. **User Secrets** (local development):
   ```bash
   dotnet user-secrets set "IdentityServer:LicenseKey" "your-license-key"
   ```

2. **Environment variables** (CI/CD, containers):
   ```bash
   export IdentityServer__LicenseKey="your-license-key"
   ```

3. **Secret manager / Key vault** (production):
   - Azure Key Vault
   - AWS Secrets Manager
   - HashiCorp Vault

All of these integrate with `IConfiguration`, so the code stays the same regardless of the secret store.

## What Happens Without a License Key?

Without a license key, IdentityServer **runs in community/trial mode** and **logs a warning on startup**. This is acceptable for local development and testing, but a valid license is required for production use.

The behavior in community/trial mode:
- IdentityServer functions normally but logs a warning message
- There are no hard functional blocks, but you must comply with the [license terms](https://duendesoftware.com/products/identityserver)

## Choosing the Right Edition

The license edition depends on your client inventory:
- Count **interactive clients** (authorization code grant — web apps, SPAs, native apps)
- Count **non-interactive clients** (client credentials — machine-to-machine)

Use the Migration Analysis Tool against your running IdentityServer4 instance to get these counts automatically before purchasing.
