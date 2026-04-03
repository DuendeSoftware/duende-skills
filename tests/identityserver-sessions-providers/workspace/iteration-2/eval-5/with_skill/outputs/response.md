# Custom Dynamic Provider Type for Google Authentication

Here's how to create a custom dynamic provider type for Google authentication in Duende IdentityServer. This involves three components: a custom `IdentityProvider` class, handler registration, and an options configuration class.

## Step 1: GoogleIdentityProvider Class

```csharp
// GoogleIdentityProvider.cs
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

This class extends `IdentityProvider` and uses the **indexer pattern** (`this["PropertyName"]`) for property storage. The indexer stores values in the provider's serialized `Properties` dictionary, which is persisted to the database.

## Step 2: Register the Handler Mapping in Program.cs

```csharp
// Program.cs (relevant section)
using Microsoft.AspNetCore.Authentication.Google;

builder.Services.AddIdentityServer(options =>
{
    options.DynamicProviders
        .AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>(
            GoogleIdentityProvider.ProviderType);
})
    // ... rest of configuration
```

This registers the mapping between the `GoogleIdentityProvider` entity type, the `GoogleHandler` authentication handler, and the `GoogleOptions` options class. The string `"google"` identifies this provider type in the database.

## Step 3: ConfigureAuthenticationOptions Implementation

```csharp
// GoogleDynamicConfigureOptions.cs
using Duende.IdentityServer;
using Duende.IdentityServer.Configuration;
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

        googleOptions.ClientId = googleProvider.ClientId!;
        googleOptions.ClientSecret = googleProvider.ClientSecret!;
        googleOptions.SignInScheme = context.DynamicProviderOptions.SignInScheme;
        googleOptions.CallbackPath = context.PathPrefix + "/signin";
    }
}
```

This class derives from `ConfigureAuthenticationOptions<GoogleOptions, GoogleIdentityProvider>` and maps the stored provider properties to the `GoogleOptions`. It sets:
- **`ClientId`** and **`ClientSecret`** from the stored provider entity
- **`SignInScheme`** from the dynamic provider options (ensures the sign-in goes through IdentityServer's external cookie scheme)
- **`CallbackPath`** following the dynamic provider convention (`/federation/{scheme}/signin`)

## Step 4: Register the Configuration Class

```csharp
// Program.cs
builder.Services.ConfigureOptions<GoogleDynamicConfigureOptions>();
```

## Complete Program.cs Update

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Authentication.Google;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer(options =>
{
    options.DynamicProviders
        .AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>(
            GoogleIdentityProvider.ProviderType);
})
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("catalog.read", "Read access to the catalog"),
        new ApiScope("catalog.write", "Write access to the catalog"),
        new ApiScope("orders.manage", "Manage orders")
    })
    .AddInMemoryClients(new List<Client>
    {
        // ... existing clients
    });

// Register the dynamic Google options configurator
builder.Services.ConfigureOptions<GoogleDynamicConfigureOptions>();

// Keep existing authentication (the static Google registration can be removed
// once it's been converted to a dynamic provider in the store)
builder.Services.AddAuthentication()
    .AddOpenIdConnect("EntraId", "Microsoft Entra ID", options =>
    {
        options.Authority = builder.Configuration["ExternalProviders:EntraId:Authority"];
        options.ClientId = builder.Configuration["ExternalProviders:EntraId:ClientId"];
        options.ClientSecret = builder.Configuration["ExternalProviders:EntraId:ClientSecret"];
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.ResponseType = "code";
    });

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
```

## Seeding a Dynamic Google Provider

```csharp
// To add a Google provider to the store:
context.IdentityProviders.Add(new GoogleIdentityProvider
{
    Scheme = "Google",
    DisplayName = "Google",
    ClientId = configuration["ExternalProviders:Google:ClientId"],
    ClientSecret = configuration["ExternalProviders:Google:ClientSecret"],
    Enabled = true
}.ToEntity());
```
