Here's how to set up Duende IdentityServer with the EF Core configuration and operational stores on SQL Server, with the migrations assembly pointed at the host project and token cleanup running every 30 minutes.

## Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

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

        // Run token cleanup every 30 minutes (value is in seconds).
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800;
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

### Notes

- **`GetConnectionString("IdentityServer")`** reads the `ConnectionStrings:IdentityServer` value from `appsettings.json`.
- **`MigrationsAssembly(migrationsAssembly)`** must be set to the host project's assembly name (via `typeof(Program).Assembly.GetName().Name`). Without it, EF looks for the migrations inside the Duende EF package and can't find the ones you generate in this project.
- **`TokenCleanupInterval`** is expressed in seconds, so 30 minutes = `1800`. It only runs when `EnableTokenCleanup = true`.

### Generating migrations

Since the two DbContexts live in the Duende package but the migrations belong in your project, generate one migration per context:

```bash
dotnet ef migrations add InitialConfig -c ConfigurationDbContext -o Migrations/Config
dotnet ef migrations add InitialOperational -c PersistedGrantDbContext -o Migrations/Operational

dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```
