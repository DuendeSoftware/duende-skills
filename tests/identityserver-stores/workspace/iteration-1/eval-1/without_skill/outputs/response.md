# Setting Up EF Core Stores for IdentityServer

```csharp
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);

        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800;
    });

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

This registers both the configuration and operational stores with SQL Server and enables token cleanup every 30 minutes.
