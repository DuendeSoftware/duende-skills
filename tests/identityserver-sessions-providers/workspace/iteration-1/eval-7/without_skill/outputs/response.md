# Configuring Session Cleanup

Here's how to configure the automatic cleanup of expired sessions.

## Configuration

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Run cleanup every 5 minutes
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);

    // Process 200 records per batch
    options.ServerSideSessions.RemoveExpiredSessionsBatchSize = 200;

    // Don't send back-channel logout on cleanup
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = false;
})
    .AddServerSideSessions()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });
```

## Notes

- The cleanup job runs in the background and removes expired session records
- Batch processing prevents overwhelming the database with large deletes
- Disable back-channel logout if clients don't support it
- For multi-instance deployments, consider using distributed locking to avoid concurrent cleanup runs