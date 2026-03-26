# Custom Session Store with Redis

To use Redis instead of EF Core for session storage, implement the session store interface and register it.

## Registration

```csharp
builder.Services.AddIdentityServer()
    .AddServerSideSessions()
    .AddServerSideSessionStore<RedisSessionStore>();
```

## Implementation

```csharp
public class RedisSessionStore : IServerSideSessionStore
{
    private readonly IConnectionMultiplexer _redis;

    public RedisSessionStore(IConnectionMultiplexer redis)
    {
        _redis = redis;
    }

    public async Task CreateSessionAsync(ServerSideSession session,
        CancellationToken cancellationToken = default)
    {
        var db = _redis.GetDatabase();
        var serialized = JsonSerializer.Serialize(session);
        await db.StringSetAsync($"session:{session.Key}", serialized);
    }

    // Implement other methods: GetSessionAsync, UpdateSessionAsync, DeleteSessionAsync, etc.
}
```

## Session Data

The session stores the user's authentication state including their claims and session metadata. The data includes:

- Subject ID (the user's unique identifier)
- Session ID (the session's unique identifier)
- Creation and expiration timestamps
- The serialized authentication ticket

## Notes

- Consider setting TTL on Redis keys matching the session expiration
- Use Redis sorted sets for efficient querying by expiration time
- Ensure Redis is configured for persistence if sessions must survive restarts