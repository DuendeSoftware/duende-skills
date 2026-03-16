# Server-Side Sessions with EF Core

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);

        options.EnableTokenCleanup = true;
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 300;
    })
    .AddServerSideSessions();
```

This enables server-side sessions and configures token cleanup with consumed token removal after 300 seconds.
