# Custom Dynamic Provider Type for Google Authentication

Here's how to create a custom dynamic provider type for Google authentication in Duende IdentityServer.

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

The `GoogleIdentityProvider` class extends `IdentityProvider` with a `"google"` provider type constant. Properties use the **indexer pattern** (`this["ClientId"]`) to store values in the underlying `Properties` dictionary, which is serialized to the database by the configuration store.

## Step 2: Register the Handler Mapping in Program.cs

```csharp
using Microsoft.AspNetCore.Authentication.Google;

builder.Services.AddIdentityServer(options =>
{
    options.DynamicProviders
        .AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>(
            GoogleIdentityProvider.ProviderType);
})
    // ... other configuration
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddConfigurationStoreCache();
```

This tells IdentityServer that when it encounters an identity provider record with type `"google"`, it should use `GoogleHandler` as the authentication handler, `GoogleOptions` as the options type, and `GoogleIdentityProvider` as the model type.

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

Register it in `Program.cs`:

```csharp
builder.Services.ConfigureOptions<GoogleDynamicConfigureOptions>();
```

## Step 4: Seed a Google Provider

To use the existing Google config from `appsettings.json`:

```csharp
// SeedData.cs or in Program.cs
var googleProvider = new GoogleIdentityProvider
{
    Scheme = "Google",
    DisplayName = "Google (dynamic)",
    Enabled = true,
    ClientId = builder.Configuration["ExternalProviders:Google:ClientId"],
    ClientSecret = builder.Configuration["ExternalProviders:Google:ClientSecret"]
};

context.IdentityProviders.Add(googleProvider.ToEntity());
await context.SaveChangesAsync();
```

## How It All Fits Together

1. **`GoogleIdentityProvider`** stores the Google-specific configuration (ClientId, ClientSecret) using the indexer pattern, which serializes to the `Properties` JSON column in the configuration store.
2. **`AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>`** registers the mapping so IdentityServer knows how to instantiate the authentication handler for this provider type.
3. **`GoogleDynamicConfigureOptions`** derives from `ConfigureAuthenticationOptions<GoogleOptions, GoogleIdentityProvider>` and maps the stored properties to `GoogleOptions`. It also sets `SignInScheme` to ensure the external login cookie is used, and `CallbackPath` to follow the dynamic provider convention.
