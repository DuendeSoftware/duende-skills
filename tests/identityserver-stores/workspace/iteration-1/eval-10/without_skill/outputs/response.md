# Operational Store Configuration

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "identity_ops";

        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);

        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 900;
        options.TokenCleanupBatchSize = 500;
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 600;
    });
```