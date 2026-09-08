# Shorter Access Token Lifetimes and Token Cleanup

Long-lived JWT access tokens are risky because they can't be revoked before expiry, so shortening them is a good security move. Below are the reduced lifetimes and the operational store cleanup configuration.

## Access token lifetimes

Set `AccessTokenLifetime` (in seconds) on each client:

```csharp
new Client
{
    ClientId = "web_app",
    // ...
    AccessTokenLifetime = 300 // 5 minutes (was 3600)
},
new Client
{
    ClientId = "m2m_client",
    // ...
    AccessTokenLifetime = 600 // 10 minutes
},
new Client
{
    ClientId = "mobile_app",
    // ...
    AccessTokenLifetime = 300 // 5 minutes
}
```

## Token cleanup on the operational store

To clean up tokens you need an operational store (e.g. `AddOperationalStore` with EF Core). Enable cleanup and set the interval to 30 minutes:

```csharp
builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.EnableTokenCleanup = true;    // enable background cleanup
        options.TokenCleanupInterval = 1800;  // every 30 minutes (in seconds)
        options.RemoveConsumedTokens = true;  // also remove consumed tokens
    });
```

- `EnableTokenCleanup = true` starts the periodic cleanup process.
- `TokenCleanupInterval = 1800` runs it every 30 minutes.
- `RemoveConsumedTokens = true` makes it clean up consumed tokens as well as expired ones.

For the "5-minute delay after consumption" part, I'm not aware of a dedicated built-in option for delaying consumed-token removal — the cleanup simply removes consumed tokens on its next pass once `RemoveConsumedTokens` is enabled. If you need a strict delay you may have to handle that in a custom cleanup step. Setting the cleanup interval to a low value keeps the store tidy in any case.
