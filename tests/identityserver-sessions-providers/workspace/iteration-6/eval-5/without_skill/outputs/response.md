# Custom dynamic provider type for Google

## Model

```csharp
using Duende.IdentityServer.Models;

public class GoogleIdentityProvider : IdentityProvider
{
    public GoogleIdentityProvider() : base("google") { }
    public GoogleIdentityProvider(IdentityProvider other) : base("google", other) { }

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

## Options configuration

```csharp
using Duende.IdentityServer.Hosting.DynamicProviders;
using Microsoft.AspNetCore.Authentication.Google;

public class GoogleDynamicConfigureOptions : ConfigureAuthenticationOptions<GoogleOptions, GoogleIdentityProvider>
{
    public GoogleDynamicConfigureOptions(IHttpContextAccessor accessor, ILogger<GoogleDynamicConfigureOptions> logger)
        : base(accessor, logger) { }

    protected override void Configure(ConfigureAuthenticationContext<GoogleOptions, GoogleIdentityProvider> context)
    {
        context.AuthenticationOptions.ClientId = context.IdentityProvider.ClientId!;
        context.AuthenticationOptions.ClientSecret = context.IdentityProvider.ClientSecret!;
        context.AuthenticationOptions.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        context.AuthenticationOptions.CallbackPath = context.PathPrefix + "/signin";
    }
}
```

## Program.cs

```csharp
builder.Services.AddIdentityServer(options =>
    {
        options.DynamicProviders.AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>("google");
    })
    .AddConfigurationStore(...)   // IdP store, e.g. EF
    ...;

builder.Services.ConfigureOptions<GoogleDynamicConfigureOptions>();
builder.Services.AddHttpContextAccessor();
```

## Seeding from existing config

```csharp
var google = builder.Configuration.GetSection("ExternalProviders:Google");
ctx.IdentityProviders.Add(new GoogleIdentityProvider
{
    Scheme = "google-dynamic",
    DisplayName = "Google",
    ClientId = google["ClientId"],
    ClientSecret = google["ClientSecret"]
}.ToEntity());
```

Remove the static `.AddGoogle("Google", ...)` to avoid conflicts. Provider properties are stored as a JSON blob in the store; keep ClientSecret protected (e.g. encrypt) since it's stored in the DB.
