# Custom Session Store with Redis

You can implement a custom session store to replace the default Entity Framework-based storage. Here's how to set it up.

## Registering the Custom Store

To use your Redis-based session store, register it with IdentityServer's server-side session feature:

```csharp
// Program.cs
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(/* ... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryClients(/* ... */)
    .AddServerSideSessions<RedisSessionStore>();
```

This tells IdentityServer to use your `RedisSessionStore` as the backing store for server-side sessions instead of the default EF Core implementation.

## What Gets Stored

The server-side session stores the user's authentication session data. This includes the claims principal and authentication properties that make up the user's login session. Essentially, it's the session cookie contents moved server-side so you can manage and revoke sessions centrally.

The session data includes things like:
- The user's claims (sub, name, email, etc.)
- Authentication method and time
- Session identifiers
- Any custom authentication properties

## Querying Sessions

When implementing the store, you'll want to support querying by common fields. The main fields you can query on are:

- **Subject ID** — the user's `sub` claim, to find all sessions for a given user
- **Session ID** — the `sid` claim, to find a specific session

You can use Redis secondary indices or sorted sets to make these lookups efficient.

## Skeleton Implementation

```csharp
using Duende.IdentityServer.Stores;

public class RedisSessionStore : IServerSideSessionStore
{
    private readonly IConnectionMultiplexer _redis;

    public RedisSessionStore(IConnectionMultiplexer redis)
    {
        _redis = redis;
    }

    public Task CreateSessionAsync(ServerSideSession session, CancellationToken cancellationToken = default)
    {
        // Serialize and store the session in Redis
        // Key by session.Key, index by session.SubjectId and session.SessionId
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

    public Task<IReadOnlyCollection<ServerSideSession>> GetSessionsAsync(SessionFilter filter, CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException();
    }

    public Task DeleteSessionsAsync(SessionFilter filter, CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException();
    }

    public Task<GetSessionsResult> GetAndRemoveExpiredSessionsAsync(int count, CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException();
    }

    public Task<QueryResult<ServerSideSession>> QuerySessionsAsync(SessionQuery filter = null, CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException();
    }
}
```

Make sure to set Redis key expiration based on the session lifetime so expired sessions are automatically cleaned up by Redis TTL.
