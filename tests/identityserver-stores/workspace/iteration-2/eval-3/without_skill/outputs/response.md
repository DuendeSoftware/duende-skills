# Separate Schemas for Configuration and Operational Tables

```csharp
var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.DefaultSchema = "idscfg";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "idsop";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

This puts configuration tables in the `idscfg` schema and operational tables in the `idsop` schema. You may also want to configure separate migration history tables per schema.
