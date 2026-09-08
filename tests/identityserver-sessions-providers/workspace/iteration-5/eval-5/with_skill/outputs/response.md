# Custom Dynamic Provider Type: Google

To make Google a *dynamic* (database-driven) provider you need three pieces: a custom `IdentityProvider` subclass that carries the Google settings, a handler-type registration, and a `ConfigureAuthenticationOptions` implementation that maps your stored properties onto `GoogleOptions`.

> Custom dynamic provider types build on the dynamic providers feature, which is **Enterprise Edition**.

## Step 1 — `GoogleIdentityProvider`

Custom identity providers extend `IdentityProvider` and store their extra settings via the base class's string indexer (this is how the data round-trips through the store's `Properties` bag). Use a `ProviderType` constant that names the handler.

```csharp
using Duende.IdentityServer.Models;

public class GoogleIdentityProvider : IdentityProvider
{
    public const string ProviderType = "google";

    public GoogleIdentityProvider() : base(ProviderType) { }

    // Indexer pattern -> persisted in the IdentityProvider Properties dictionary
    public string? ClientId
    {
        get => this["ClientId"];
        set => this["ClientId"] = value;
    }

    public string? ClientSecret
    {
        get => this["ClientSecret"];
        set => this["ClientSecret"] = value;
    }
}
```

## Step 2 — register the handler mapping in Program.cs

Tell IdentityServer which ASP.NET Core handler/options pair backs the `"google"` provider type:

```csharp
using Microsoft.AspNetCore.Authentication.Google;

builder.Services.AddIdentityServer(options =>
{
    options.DynamicProviders
        .AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>(
            GoogleIdentityProvider.ProviderType);
});
```

## Step 3 — map stored properties onto `GoogleOptions`

Derive from `ConfigureAuthenticationOptions<GoogleOptions, GoogleIdentityProvider>`. Map your `ClientId`/`ClientSecret`, and set `SignInScheme` and `CallbackPath` from the dynamic-provider context so the federation callback convention is honored.

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.Authentication.Google;
using Microsoft.Extensions.Logging;

class GoogleDynamicConfigureOptions
    : ConfigureAuthenticationOptions<GoogleOptions, GoogleIdentityProvider>
{
    public GoogleDynamicConfigureOptions(
        IHttpContextAccessor httpContextAccessor,
        ILogger<GoogleDynamicConfigureOptions> logger)
        : base(httpContextAccessor, logger) { }

    protected override void Configure(
        ConfigureAuthenticationContext<GoogleOptions, GoogleIdentityProvider> context)
    {
        var google = context.IdentityProvider;      // your GoogleIdentityProvider
        var options = context.AuthenticationOptions; // the GoogleOptions to fill

        options.ClientId = google.ClientId!;
        options.ClientSecret = google.ClientSecret!;

        // Sign-in scheme and dynamic callback path
        options.SignInScheme = context.DynamicProviderOptions.SignInScheme;
        options.CallbackPath = context.PathPrefix + "/signin";
    }
}
```

Register it:

```csharp
builder.Services.ConfigureOptions<GoogleDynamicConfigureOptions>();
```

## Step 4 — seed a Google provider using the existing config

Reuse the `ExternalProviders:Google` values from `appsettings.json`:

```csharp
var googleCfg = builder.Configuration.GetSection("ExternalProviders:Google");

// e.g. into an in-memory store or ConfigurationDbContext
new GoogleIdentityProvider
{
    Scheme = "google",
    DisplayName = "Google",
    Enabled = true,
    ClientId = googleCfg["ClientId"],
    ClientSecret = googleCfg["ClientSecret"],
};
```

## How it fits together

- The **`ProviderType = "google"`** constant links the stored provider record → the handler registration in Step 2.
- The **indexer pattern** (`this["ClientId"]`) is required: it stores your custom fields in the base `IdentityProvider` `Properties` dictionary so they persist and load from the store.
- **`AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>`** wires the Google authentication handler into the dynamic-provider pipeline.
- The **`ConfigureAuthenticationOptions`-derived** class runs per request/scheme and translates the stored `GoogleIdentityProvider` into a live `GoogleOptions`, including the `SignInScheme` and the `~/federation/google/signin` `CallbackPath`.
