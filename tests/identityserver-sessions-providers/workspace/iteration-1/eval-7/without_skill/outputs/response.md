# Configuring Session Cleanup

Here's how to configure session cleanup in Duende IdentityServer.

## Updated Program.cs

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Run cleanup every 5 minutes
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(5);

    // Process 200 records per batch
    options.ServerSideSessions.RemoveExpiredSessionsBatchSize = 200;

    // Disable back-channel logout on expiration
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = false;
})
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("catalog.read", "Read access to the catalog"),
        new ApiScope("catalog.write", "Write access to the catalog"),
        new ApiScope("orders.manage", "Manage orders")
    })
    .AddInMemoryClients(new List<Client>
    {
        // ... existing clients ...
    })
    .AddServerSideSessions();
```

## Summary

- The cleanup job runs every 5 minutes instead of the default 10 minutes
- Each batch processes up to 200 expired sessions
- Back-channel logout is disabled since clients don't support it
- Server-side sessions are enabled via `AddServerSideSessions()`

This should help clear out expired sessions more aggressively. Make sure your database can handle the additional load from the more frequent cleanup.
