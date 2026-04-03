# Separate Databases

```csharp
var builder = WebApplication.CreateBuilder(args);

var configConnStr = builder.Configuration.GetConnectionString("ConfigDb");
var opsConnStr = builder.Configuration.GetConnectionString("OpsDb");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(configConnStr);
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(opsConnStr);
    });

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

Update appsettings.json:
```json
{
  "ConnectionStrings": {
    "ConfigDb": "Server=localhost;Database=IdentityServer_Config;Trusted_Connection=True",
    "OpsDb": "Server=localhost;Database=IdentityServer_Ops;Trusted_Connection=True"
  }
}
```
