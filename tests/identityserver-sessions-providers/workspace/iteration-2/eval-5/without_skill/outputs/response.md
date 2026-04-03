# Custom Dynamic Provider Type for Google Authentication

To add Google as a dynamic provider in Duende IdentityServer, you'll need to create a custom identity provider model, register the handler, and create an options configuration class.

## Step 1: GoogleIdentityProvider Class

```csharp
// GoogleIdentityProvider.cs
using Duende.IdentityServer.Models;

public class GoogleIdentityProvider : IdentityProvider
{
    public const string ProviderType = "google";

    public GoogleIdentityProvider() : base(ProviderType) { }

    public string? ClientId { get; set; }
    public string? ClientSecret { get; set; }
}
```

This extends `IdentityProvider` and adds properties for the Google-specific configuration.

## Step 2: Register the Handler in Program.cs

```csharp
// Program.cs
using Microsoft.AspNetCore.Authentication.Google;

builder.Services.AddIdentityServer(options =>
{
    options.DynamicProviders
        .AddProviderType<GoogleHandler, GoogleOptions, GoogleIdentityProvider>(
            GoogleIdentityProvider.ProviderType);
});
```

## Step 3: Options Configuration Class

```csharp
// GoogleDynamicConfigureOptions.cs
using Microsoft.AspNetCore.Authentication.Google;
using Microsoft.Extensions.Options;

public class GoogleDynamicConfigureOptions : IConfigureNamedOptions<GoogleOptions>
{
    private readonly IConfiguration _configuration;

    public GoogleDynamicConfigureOptions(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public void Configure(string? name, GoogleOptions options)
    {
        // Map the provider properties to GoogleOptions
        var clientId = _configuration["ExternalProviders:Google:ClientId"];
        var clientSecret = _configuration["ExternalProviders:Google:ClientSecret"];

        if (clientId != null) options.ClientId = clientId;
        if (clientSecret != null) options.ClientSecret = clientSecret;
    }

    public void Configure(GoogleOptions options)
    {
        Configure(null, options);
    }
}
```

## Step 4: Register the Configuration Class

```csharp
// Program.cs
builder.Services.ConfigureOptions<GoogleDynamicConfigureOptions>();
```

## Complete Program.cs

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

builder.Services.ConfigureOptions<GoogleDynamicConfigureOptions>();

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

The dynamic Google provider can then be added to the database store and will be loaded at runtime without needing to restart the application.
