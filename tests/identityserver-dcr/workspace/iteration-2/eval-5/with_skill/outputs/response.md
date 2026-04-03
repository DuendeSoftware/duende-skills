To use persistent storage for dynamically registered clients in production, use the Entity Framework-backed client configuration store.

### 1. Add the NuGet package

```bash
dotnet add package Duende.IdentityServer.Configuration.EntityFramework
```

Updated `IdentityServer.csproj`:

```xml
<ItemGroup>
  <PackageReference Include="Duende.IdentityServer" Version="7.1.0" />
  <PackageReference Include="Duende.IdentityServer.Configuration" Version="7.1.0" />
  <PackageReference Include="Duende.IdentityServer.Configuration.EntityFramework" Version="7.1.0" />
  <PackageReference Include="Serilog.AspNetCore" Version="8.0.3" />
</ItemGroup>
```

### 2. Configure the store in Program.cs

```csharp
builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();
```

### Full Program.cs

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

// Add DCR services with Entity Framework store for production
builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDynamicClientRegistration()
    .RequireAuthorization("dcr");

app.MapRazorPages();

app.Run();
```

### Important

- **Do NOT use in-memory stores for dynamically registered clients in production.** In-memory stores lose all registered clients when the application restarts and don't work with multiple instances.
- `AddClientConfigurationStore()` uses Entity Framework to persist dynamically registered clients to the same database IdentityServer uses.
- The EF store handles client secret hashing and all CRUD operations for the client lifecycle.
