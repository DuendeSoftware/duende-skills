# Adding Dynamic Client Registration to Duende IdentityServer

Dynamic Client Registration (DCR) allows OAuth 2.0 clients to register themselves programmatically per RFC 7591.

## Step 1: Install the Required Package

Duende IdentityServer has a separate package for DCR support:

```bash
dotnet add package Duende.IdentityServer.Configuration
```

## Step 2: Configure DCR in Program.cs

You'll need to add the DCR services and map the endpoint:

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

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

// Add DCR support
builder.Services.AddIdentityServerConfiguration();

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

// Map the DCR endpoint
app.MapDynamicClientRegistration();

app.MapRazorPages();

app.Run();
```

## Step 3: Secure the Endpoint

You should consider adding authentication and authorization to the DCR endpoint to prevent unauthorized client registrations. You can do this using standard ASP.NET Core authorization policies:

```csharp
app.MapDynamicClientRegistration()
    .RequireAuthorization("some-policy");
```

## Notes

- The DCR endpoint is typically available at `/connect/dcr`
- Clients can POST registration requests with their desired configuration
- The response includes the generated `client_id` and `client_secret`
