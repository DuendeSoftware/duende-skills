# Server-Side Sessions Setup

```csharp
var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    })
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
        options.EnableTokenCleanup = true;
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 300;
    });

// Server-side sessions might need additional configuration
// Check Duende documentation for AddServerSideSessions()

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

Token cleanup is enabled with consumed token removal after a 5-minute delay.
