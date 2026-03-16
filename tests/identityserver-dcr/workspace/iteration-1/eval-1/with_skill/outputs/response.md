# Adding Dynamic Client Registration to Duende IdentityServer

## Prerequisites

DCR requires the **Business Edition** or higher license of Duende IdentityServer. Community Edition does not support DCR.

## Step 1: Add the NuGet Package

```bash
dotnet add package Duende.IdentityServer.Configuration
```

Your updated `.csproj` will include:

```xml
<PackageReference Include="Duende.IdentityServer.Configuration" Version="7.1.0" />
```

## Step 2: Register DCR Services

In your `Program.cs`, add the DCR configuration services after your existing IdentityServer setup:

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// IdentityServer registration with minimal configuration
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "API 1"),
        new ApiScope("api2", "API 2"),
        new ApiScope("IdentityServer.Configuration", "IdentityServer Configuration API")
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web.app",
            ClientName = "Main Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://app.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "email", "api1" },
            AllowOfflineAccess = true
        },
        new Client
        {
            ClientId = "dcr.manager",
            ClientName = "DCR Management Client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("dcr-secret".Sha256()) },
            AllowedScopes = { "IdentityServer.Configuration" }
        }
    });

// Add DCR configuration services
builder.Services.AddIdentityServerConfiguration();

// Secure the DCR endpoint with JWT bearer authentication
builder.Services.AddAuthentication()
    .AddJwtBearer("dcr", options =>
    {
        options.Authority = "https://identity.example.com";
        options.Audience = "IdentityServer.Configuration";
        options.TokenValidationParameters.ValidTypes = new[] { "at+jwt" };
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("dcr", policy =>
    {
        policy.AddAuthenticationSchemes("dcr");
        policy.RequireAuthenticatedUser();
        policy.RequireClaim("scope", "IdentityServer.Configuration");
    });
});

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

// Map the DCR endpoint with authorization
app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.MapRazorPages();

app.Run();
```

## Key Points

1. **`AddIdentityServerConfiguration()`** registers the DCR services including the default validator and in-memory client configuration store.
2. **`MapDynamicClientRegistration()`** maps the `/connect/dcr` endpoint.
3. **Always secure the endpoint** — never expose `MapDynamicClientRegistration()` without `RequireAuthorization()`. The example above uses JWT bearer authentication with a scope check.
4. **Business Edition or higher** is required. Attempting to use DCR with Community Edition will result in a license error.

> **Warning**: For production, replace the in-memory client store with a persistent store (e.g., `AddClientConfigurationStore()` from the `Duende.IdentityServer.Configuration.EntityFramework` package) so dynamically registered clients survive restarts.
