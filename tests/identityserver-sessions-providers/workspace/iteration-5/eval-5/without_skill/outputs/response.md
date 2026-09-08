# Adding Google as a Custom Dynamic Provider

Duende IdentityServer's dynamic providers support OIDC out of the box. For a non-OIDC handler like Google you register a custom provider type: a custom `IdentityProvider` model, a handler mapping, and an options-configuration class that projects your stored settings onto `GoogleOptions`.

## 1) Custom identity provider model

Extend `IdentityProvider` and add the Google-specific fields. Use a provider-type constant to identify the handler.

```csharp
using Duende.IdentityServer.Models;

public class GoogleIdentityProvider : IdentityProvider
{
    public const string ProviderType = "google";

    public GoogleIdentityProvider() : base(ProviderType) { }

    public string? ClientId { get; set; }
    public string? ClientSecret { get; set; }
}
```

## 2) Register the handler type in Program.cs

Map the `"google"` provider type to the Google authentication handler and options:

```csharp
using Microsoft.AspNetCore.Authentication.Google;

builder.Services.AddIdentityServer(options =>
{
    options.DynamicProviders
        .AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>(
            GoogleIdentityProvider.ProviderType);
});
```

## 3) Configure the GoogleOptions from the provider

Provide a configuration class that maps your model's properties onto `GoogleOptions`. Derive from Duende's `ConfigureAuthenticationOptions<GoogleOptions, GoogleIdentityProvider>`:

```csharp
using Microsoft.AspNetCore.Authentication.Google;

class GoogleConfigureOptions
    : ConfigureAuthenticationOptions<GoogleOptions, GoogleIdentityProvider>
{
    public GoogleConfigureOptions(
        IHttpContextAccessor httpContextAccessor,
        ILogger<GoogleConfigureOptions> logger)
        : base(httpContextAccessor, logger) { }

    protected override void Configure(
        ConfigureAuthenticationContext<GoogleOptions, GoogleIdentityProvider> context)
    {
        var provider = context.IdentityProvider;
        var options = context.AuthenticationOptions;

        options.ClientId = provider.ClientId!;
        options.ClientSecret = provider.ClientSecret!;

        options.SignInScheme = context.DynamicProviderOptions.SignInScheme;
        options.CallbackPath = context.PathPrefix + "/signin";
    }
}
```

Register it:

```csharp
builder.Services.ConfigureOptions<GoogleConfigureOptions>();
```

## 4) Use the existing Google config

Seed a `GoogleIdentityProvider` using the values from `appsettings.json`:

```csharp
var cfg = builder.Configuration.GetSection("ExternalProviders:Google");

var google = new GoogleIdentityProvider
{
    Scheme = "google",
    DisplayName = "Google",
    Enabled = true,
    ClientId = cfg["ClientId"],
    ClientSecret = cfg["ClientSecret"]
};
// add to your in-memory or EF-backed identity provider store
```

## Summary

- `GoogleIdentityProvider` extends `IdentityProvider` with a `"google"` provider-type constant.
- `AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>` binds the handler.
- The `ConfigureAuthenticationOptions`-derived class maps `ClientId`/`ClientSecret` and sets `SignInScheme` and the `CallbackPath`.
