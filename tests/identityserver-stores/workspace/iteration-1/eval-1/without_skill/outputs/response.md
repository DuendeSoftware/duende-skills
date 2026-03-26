# EF Core Stores Setup

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

Run EF migrations to create the database tables for both contexts.