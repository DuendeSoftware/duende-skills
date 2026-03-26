# Custom Dynamic Provider Type for Google Authentication

To add Google as a dynamic provider type in Duende IdentityServer, you need three components: a custom `IdentityProvider` class, handler registration, and an options mapper.

## Step 1: GoogleIdentityProvider Class

```csharp
using Duende.IdentityServer.Models;

public class GoogleIdentityProvider : IdentityProvider
{
    public const string ProviderType = "google";

    public GoogleIdentityProvider() : base(ProviderType) { }

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

The `this["key"]` indexer pattern stores properties in the base class's `Properties` dictionary, which is automatically serialized to the database.

## Step 2: Register the Handler Mapping in Program.cs

```csharp
using Microsoft.AspNetCore.Authentication.Google;

builder.Services.AddIdentityServer(options =>
{
    options.DynamicProviders
        .AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>(
            GoogleIdentityProvider.ProviderType);
})
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    })
    .AddConfigurationStoreCache();
```

## Step 3: ConfigureAuthenticationOptions Implementation

```csharp
using Duende.IdentityServer.Configuration;
using Microsoft.AspNetCore.Authentication.Google;

public class GoogleDynamicConfigureOptions
    : ConfigureAuthenticationOptions<GoogleOptions, GoogleIdentityProvider>
{
    public GoogleDynamicConfigureOptions(
        IHttpContextAccessor httpContextAccessor,
        ILogger<GoogleDynamicConfigureOptions> logger)
        : base(httpContextAccessor, logger) { }

    protected override void Configure(
        ConfigureAuthenticationContext<GoogleOptions, GoogleIdentityProvider> context)
    {
        var googleProvider = context.IdentityProvider;
        var googleOptions = context.AuthenticationOptions;

        googleOptions.ClientId = googleProvider.ClientId!;
        googleOptions.ClientSecret = googleProvider.ClientSecret!;
        googleOptions.SignInScheme = context.DynamicProviderOptions.SignInScheme;
        googleOptions.CallbackPath = context.PathPrefix + "/signin";
    }
}
```

Register it:

```csharp
builder.Services.ConfigureOptions<GoogleDynamicConfigureOptions>();
```

## Step 4: Seed a Google Provider

```csharp
context.IdentityProviders.Add(new GoogleIdentityProvider
{
    Scheme = "google-dynamic",
    DisplayName = "Google (Dynamic)",
    ClientId = builder.Configuration["ExternalProviders:Google:ClientId"],
    ClientSecret = builder.Configuration["ExternalProviders:Google:ClientSecret"],
    Enabled = true
}.ToEntity());
```

## Key Points

- The indexer pattern (`this["ClientId"]`) stores values in the `Properties` dictionary for automatic serialization
- `AddProviderType<THandler, TOptions, TIdentityProvider>()` maps the handler to the provider type
- `ConfigureAuthenticationOptions<TOptions, TIdentityProvider>` bridges provider data to auth options
- `SignInScheme` and `CallbackPath` must be set correctly for the dynamic provider flow