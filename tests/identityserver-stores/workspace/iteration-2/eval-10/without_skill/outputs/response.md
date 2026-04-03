# Token Cleanup Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "identity_ops";
        options.ConfigureDbContext = b => b.UseSqlServer(connectionString);

        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 900;
        options.TokenCleanupBatchSize = 500;
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 600;
    });

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

This configures aggressive token cleanup for high-traffic scenarios with a 500-token batch size and 15-minute interval.
