# Custom IServerSideSessionStore with Redis

Here's how to register a custom session store backed by Redis for Duende IdentityServer.

## Registration

```csharp
// Program.cs
builder.Services.AddIdentityServer()
    .AddServerSideSessions()
    .AddServerSideSessionStore<RedisSessionStore>();
```

You can also register the store directly via DI:

```csharp
builder.Services.AddSingleton<IServerSideSessionStore, RedisSessionStore>();
builder.Services.AddIdentityServer()
    .AddServerSideSessions();
```

## What's Stored in a Session

Each session record contains:
- A unique key identifying the session
- The user's subject ID
- The session ID  
- Creation and renewal timestamps
- Expiration time
- The serialized authentication ticket

The authentication ticket includes all claims and authentication properties for the user's session.

## Implementation

Your `RedisSessionStore` needs to implement `IServerSideSessionStore`:

```csharp
public class RedisSessionStore : IServerSideSessionStore
{
    private readonly IConnectionMultiplexer _redis;

    public RedisSessionStore(IConnectionMultiplexer redis)
    {
        _redis = redis;
    }

    public Task CreateSessionAsync(ServerSideSession session, CancellationToken cancellationToken = default)
    {
        // Store session in Redis using session.Key as the key
        throw new NotImplementedException();
    }

    public Task<ServerSideSession?> GetSessionAsync(string key, CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException();
    }

    public Task UpdateSessionAsync(ServerSideSession session, CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException();
    }

    public Task DeleteSessionAsync(string key, CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException();
    }

    // ... additional query and cleanup methods
}
```

## Notes

- Make sure your Redis instance is available and properly configured for production use
- Consider using Redis sorted sets or secondary indices to efficiently query sessions by user
- Data Protection keys should be shared across instances for consistent session decryption
