# Setting Up EF-backed Client Configuration Store for DCR

For production deployments, you should never use in-memory stores for dynamically registered clients — they won't survive restarts and aren't shared across instances.

## Step 1: Add the EF Package

```bash
dotnet add package Duende.IdentityServer.Configuration.EntityFramework
```

Your updated `.csproj` will include:

```xml
<PackageReference Include="Duende.IdentityServer.Configuration" Version="7.1.0" />
<PackageReference Include="Duende.IdentityServer.Configuration.EntityFramework" Version="7.1.0" />
```

## Step 2: Configure the Store

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

// Add DCR configuration with the EF-backed client store
builder.Services.AddIdentityServerConfiguration()
    .AddClientConfigurationStore();

// ... authentication and authorization setup ...

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

## How It Works

1. **`AddClientConfigurationStore()`** registers the Entity Framework-backed `IClientConfigurationStore` that persists dynamically registered clients to your database.

2. The EF store uses the same database context patterns as the rest of IdentityServer's operational data.

3. Dynamically registered clients are stored alongside your statically configured clients but in a separate store that supports add/update/delete operations.

> **Warning**: Do **not** use in-memory stores for dynamically registered clients in production. In-memory stores lose all data on restart and are not shared across multiple instances. Always use a persistent store backed by a database.

## Connection String

Make sure your `appsettings.json` has a connection string configured:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=IdentityServer;Trusted_Connection=True;"
  }
}
```

You may need to configure the DbContext connection in the `AddClientConfigurationStore()` call or via the standard EF Core configuration depending on your setup.
