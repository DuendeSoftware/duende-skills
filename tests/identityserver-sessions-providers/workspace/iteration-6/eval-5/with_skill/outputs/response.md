# Custom dynamic provider type for Google

Dynamic providers (Enterprise edition) need three pieces: the provider model, the handler mapping, and the options mapping.

## 1. `GoogleIdentityProvider`

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

## 2. Handler registration (Program.cs)

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.DynamicProviders
        .AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>(
            GoogleIdentityProvider.ProviderType);
})
.AddConfigurationStore(/* EF store */)
.AddConfigurationStoreCache();

builder.Services.ConfigureOptions<GoogleDynamicConfigureOptions>();
```

(`GoogleHandler`/`GoogleOptions` come from `Microsoft.AspNetCore.Authentication.Google`, already referenced.)

## 3. Options mapping

```csharp
using Duende.IdentityServer.Hosting.DynamicProviders;
using Microsoft.AspNetCore.Authentication.Google;

class GoogleDynamicConfigureOptions
    : ConfigureAuthenticationOptions<GoogleOptions, GoogleIdentityProvider>
{
    public GoogleDynamicConfigureOptions(IHttpContextAccessor httpContextAccessor,
        ILogger<GoogleDynamicConfigureOptions> logger) : base(httpContextAccessor, logger) { }

    protected override void Configure(
        ConfigureAuthenticationContext<GoogleOptions, GoogleIdentityProvider> context)
    {
        var googleProvider = context.IdentityProvider;
        var googleOptions = context.AuthenticationOptions;

        googleOptions.ClientId = googleProvider.ClientId;
        googleOptions.ClientSecret = googleProvider.ClientSecret;
        googleOptions.SignInScheme = context.DynamicProviderOptions.SignInScheme;
        googleOptions.CallbackPath = context.PathPrefix + "/signin";
    }
}
```

## 4. Using the existing appsettings values

Remove the static `.AddGoogle("Google", ...)` and seed a record from `ExternalProviders:Google`:

```csharp
var google = builder.Configuration.GetSection("ExternalProviders:Google");

if (!ctx.IdentityProviders.Any(x => x.Scheme == "google"))
{
    ctx.IdentityProviders.Add(new GoogleIdentityProvider
    {
        Scheme = "google",
        DisplayName = "Google",
        Enabled = true,
        ClientId = google["ClientId"],
        ClientSecret = google["ClientSecret"]
    }.ToEntity());
    await ctx.SaveChangesAsync();
}
```

## Notes
- Register `https://<host>/federation/google/signin` as the redirect URI at Google (the `PathPrefix` is `/federation/{scheme}` by default).
- Without caching, each request reloads the provider from the store; use `AddConfigurationStoreCache()`.
- The store is read-only through `IIdentityProviderStore`; write via `ConfigurationDbContext`.
- Secrets in the provider record are stored in the database, so protect the DB.
- Show dynamic providers on the login page by merging `GetAllSchemeNamesAsync()` with static schemes.
