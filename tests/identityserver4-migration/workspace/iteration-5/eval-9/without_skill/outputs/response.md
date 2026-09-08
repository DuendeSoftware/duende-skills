# Configuring the Duende IdentityServer license key

## How to configure it

The license key is applied through `IdentityServerOptions.LicenseKey` in your `AddIdentityServer` registration:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["Duende:LicenseKey"];
});
```

(Duende also supports dropping a license file into the application's content root, but wiring the value through configuration as above is the more flexible approach and is what I'd recommend.)

## Where the key should live

Treat the license key like any other secret — **don't hardcode it and don't check it into source control** (so keep it out of a committed `appsettings.json`). Instead pull it from:

- **User Secrets** during development (`dotnet user-secrets set "Duende:LicenseKey" "..."`),
- an **environment variable** (`Duende__LicenseKey`), or
- a **secret store / key vault** in production.

Reading it via `Configuration[...]` means you can swap the backing source per environment without touching code.

## What happens if you don't supply one

Duende IdentityServer is licensed software. If no valid license key is present, it doesn't hard-fail — it will **start up and keep working, but it logs warnings** about the missing/invalid license (and there are usage thresholds tied to the edition you're licensed for). That's fine while you're developing locally, but for a production deployment you're expected to have a valid license in place; leaving it unlicensed is both a compliance issue and something the logs will keep complaining about.

So: set `options.LicenseKey` from configuration, keep the actual key in a secret store rather than in the repo, and make sure production has a real license so you're not running on warnings.
