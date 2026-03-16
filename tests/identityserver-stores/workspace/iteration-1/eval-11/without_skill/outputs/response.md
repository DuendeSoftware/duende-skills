# Separate Databases for IdentityServer Stores

Here's how to configure separate databases for configuration and operational data.

## Updated appsettings.json

```json
{
  "ConnectionStrings": {
    "IdentityServer": "Server=localhost;Database=IdentityServerDb;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True",
    "ConfigDb": "Server=localhost;Database=IdentityServer_Config;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True",
    "OpsDb": "Server=localhost;Database=IdentityServer_Ops;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True"
  },
  "Redis": {
    "ConnectionString": "localhost:6379"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.DefaultSchema = "config";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(
                builder.Configuration.GetConnectionString("ConfigDb"),
                sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "ops";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(
                builder.Configuration.GetConnectionString("OpsDb"),
                sql => sql.MigrationsAssembly(migrationsAssembly));
        options.EnableTokenCleanup = true;
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

Each store now uses its own database and schema. The configuration store uses the `config` schema and the operational store uses the `ops` schema. This provides clean separation of concerns.
