Here is the corrected `Program.cs` that wires up both the EF Core configuration store and operational store against SQL Server, sets the migrations assembly to the host project so `dotnet ef` and runtime startup resolve migrations correctly, and enables token cleanup on a 30-minute (1800-second) cadence.

## Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

// Migrations live in THIS host project, so point EF at this assembly.
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));

        // Token cleanup every 30 minutes.
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800; // seconds (30 minutes)
    });

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();

// Static configuration for seeding
public static class Config
{
    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "api-client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        }
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new ApiScope("api1", "My API")
    ];

    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    ];
}
```

## Why each piece matters

- **`AddConfigurationStore` / `AddOperationalStore`** register the two EF `DbContext` types: `ConfigurationDbContext` (clients, resources, CORS) and `PersistedGrantDbContext` (grants, device codes, signing keys, sessions).
- **`sql.MigrationsAssembly(migrationsAssembly)`** is the single most common EF setup mistake to avoid. Because the migrations you scaffold live in this host project rather than in `Duende.IdentityServer.EntityFramework.dll`, EF must be told which assembly holds them — otherwise `dotnet ef migrations add` and startup both fail to find the migrations.
- **`GetConnectionString("IdentityServer")`** reads `ConnectionStrings:IdentityServer` from `appsettings.json`, which already contains the SQL Server connection string.
- **`EnableTokenCleanup = true` + `TokenCleanupInterval = 1800`** runs the background `TokenCleanupService` every 30 minutes to purge expired grants, device codes, PAR entries, and expired server-side sessions.

## Creating the migrations

Because you own migration creation, scaffold one per context into the host project:

```shell
dotnet ef migrations add InitialIdentityServerConfigurationDb \
  --context ConfigurationDbContext \
  --output-dir Data/Migrations/IdentityServer/ConfigurationDb

dotnet ef migrations add InitialIdentityServerOperationalDb \
  --context PersistedGrantDbContext \
  --output-dir Data/Migrations/IdentityServer/OperationalDb

dotnet ef database update --context ConfigurationDbContext
dotnet ef database update --context PersistedGrantDbContext
```
