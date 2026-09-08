# Configuring the Duende IdentityServer license key

## Where to set it

The license key is set on `IdentityServerOptions.LicenseKey`, inside the `AddIdentityServer` call:

```csharp
services.AddIdentityServer(options =>
    {
        options.LicenseKey = /* loaded from configuration */;
    })
    .AddConfigurationStore(/* ... */)
    .AddOperationalStore(/* ... */);
```

In the minimal-hosting form after migration:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
});
```

## Where to store it (not in source control)

Load the key from **configuration, an environment variable, or a secret manager / key vault** — never hardcode it and **never commit it to a source-controlled `appsettings.json`**. Good options:

- **User Secrets** for local dev: `dotnet user-secrets set "IdentityServer:LicenseKey" "<key>"`
- **Environment variable**: `IdentityServer__LicenseKey` (double underscore maps to the nested config key)
- **Azure Key Vault / AWS Secrets Manager / etc.** in production, surfaced through the configuration system

Because you read it through `builder.Configuration[...]`, the same code works across all of these providers without change.

## What happens without a license key

If you don't provide a license key, IdentityServer still starts, but it runs in **community/trial mode** and **logs a warning on startup** indicating no license was found. This is acceptable for local development and testing. For production, a valid license is required — running unlicensed in production is a licensing violation and the startup warnings will make it obvious.

## Choosing the right edition

The edition you need depends on your client inventory — count interactive (authorization-code) clients vs. non-interactive (client-credentials) clients. In your `Config.cs` you have one of each (`interactive.client` and `m2m.client`), which is well within the smallest paid tiers, but validate against the current [Duende pricing/edition thresholds](https://duendesoftware.com/products/identityserver). The Migration Analysis Tool can count these automatically.
