# Separate Databases

```csharp
var configConn = builder.Configuration.GetConnectionString("ConfigDb");
var opsConn = builder.Configuration.GetConnectionString("OpsDb");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.DefaultSchema = "config";
        options.ConfigureDbContext = b => b.UseSqlServer(configConn);
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "ops";
        options.ConfigureDbContext = b => b.UseSqlServer(opsConn);
    });
```

Update appsettings.json:
```json
{
  "ConnectionStrings": {
    "ConfigDb": "Server=localhost;Database=IdentityConfig;Trusted_Connection=True;",
    "OpsDb": "Server=localhost;Database=IdentityOps;Trusted_Connection=True;"
  }
}
```