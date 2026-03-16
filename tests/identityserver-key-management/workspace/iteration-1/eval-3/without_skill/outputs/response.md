# Multi-Instance IdentityServer with EF Store and Data Protection

Here's the updated `Program.cs` with Entity Framework operational store for key storage and data protection configured for multiple instances:

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

// Data protection for multi-instance
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/shared/dataprotection-keys"));

builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web-app",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            AllowedScopes = { "openid", "profile", "api1" }
        },
        new Client
        {
            ClientId = "machine-client",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" }
        }
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "My API")
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This configures:

1. **Entity Framework Operational Store**: The `AddOperationalStore` method sets up SQL Server-backed storage for IdentityServer's operational data including signing keys. This ensures all instances behind the load balancer share the same keys.

2. **Data Protection**: `AddDataProtection()` with `PersistKeysToFileSystem` pointed to a shared directory ensures all instances can encrypt/decrypt data protection keys consistently.

Make sure the shared directory `/shared/dataprotection-keys` is accessible by all instances and that you run EF migrations to create the necessary database tables.
