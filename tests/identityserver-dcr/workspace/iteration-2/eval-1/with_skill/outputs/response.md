To add Dynamic Client Registration (DCR) to your Duende IdentityServer application, you need three things: the NuGet package, service registration, and endpoint mapping.

> **Important:** DCR requires a **Business Edition** or higher license. The Community Edition does not support DCR.

### 1. Add the NuGet package

```bash
dotnet add package Duende.IdentityServer.Configuration
```

Update your `IdentityServer.csproj`:

```xml
<ItemGroup>
  <PackageReference Include="Duende.IdentityServer" Version="7.1.0" />
  <PackageReference Include="Duende.IdentityServer.Configuration" Version="7.1.0" />
  <PackageReference Include="Serilog.AspNetCore" Version="8.0.3" />
</ItemGroup>
```

### 2. Register DCR services and map the endpoint

Update your `Program.cs`:

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

// Add DCR services (requires Business Edition or higher)
builder.Services.AddIdentityServerConfiguration();

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

// Map the DCR endpoint at /connect/dcr
// WARNING: You should secure this endpoint with an authorization policy.
// Without RequireAuthorization(), anyone can register clients.
app.MapDynamicClientRegistration()
    .RequireAuthorization();

app.MapRazorPages();

app.Run();
```

### Key points

- `AddIdentityServerConfiguration()` registers the DCR services in the DI container.
- `MapDynamicClientRegistration()` maps the `/connect/dcr` endpoint for RFC 7591 dynamic client registration.
- **Always** chain `.RequireAuthorization()` on `MapDynamicClientRegistration()` to secure the endpoint. Without it, the DCR endpoint is open to unauthenticated callers, which is a serious security risk.
