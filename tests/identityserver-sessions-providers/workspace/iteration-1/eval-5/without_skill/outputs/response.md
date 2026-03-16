# Custom Dynamic Provider Type for Google Authentication

Here's how to create a custom dynamic provider type for Google in Duende IdentityServer.

## GoogleIdentityProvider Model

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

## Register the Handler Mapping

In `Program.cs`:

```csharp
using Microsoft.AspNetCore.Authentication.Google;

builder.Services.AddIdentityServer(options =>
{
    options.DynamicProviders
        .AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>(
            GoogleIdentityProvider.ProviderType);
});
```

## Options Mapping

```csharp
using Microsoft.AspNetCore.Authentication.Google;
using Microsoft.Extensions.Options;

public class GoogleDynamicConfigureOptions : IConfigureNamedOptions<GoogleOptions>
{
    public void Configure(string? name, GoogleOptions options)
    {
        // This would need to look up the provider configuration
        // and map it to GoogleOptions
    }

    public void Configure(GoogleOptions options) { }
}
```

Register it:

```csharp
builder.Services.ConfigureOptions<GoogleDynamicConfigureOptions>();
```

## Seeding a Provider

```csharp
using var scope = app.Services.CreateScope();
var context = scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();

if (!context.IdentityProviders.Any())
{
    var provider = new GoogleIdentityProvider
    {
        Scheme = "Google",
        DisplayName = "Google",
        Enabled = true,
        ClientId = builder.Configuration["ExternalProviders:Google:ClientId"],
        ClientSecret = builder.Configuration["ExternalProviders:Google:ClientSecret"]
    };

    context.IdentityProviders.Add(provider.ToEntity());
    context.SaveChanges();
}
```

This maps the Google handler to the dynamic provider system, allowing Google providers to be managed in the database rather than hardcoded in startup.
