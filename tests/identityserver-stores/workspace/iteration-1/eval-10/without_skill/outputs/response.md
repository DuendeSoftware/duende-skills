# Advanced Token Cleanup Settings for Production

Here's the updated `Program.cs` with the production token cleanup configuration:

```csharp
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

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
        options.DefaultSchema = "identity_ops";

        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));

        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 900; // 15 minutes
        options.TokenCleanupBatchSize = 500;
        options.RemoveConsumedTokens = true;
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

This configures the operational store with a custom schema, enables cleanup every 15 minutes, and processes 500 tokens per batch. The `RemoveConsumedTokens` setting ensures used tokens are cleaned up as well.

For the load-balanced instances, the built-in cleanup should handle concurrent execution via database-level locking, so each instance running cleanup will not conflict with the others.
