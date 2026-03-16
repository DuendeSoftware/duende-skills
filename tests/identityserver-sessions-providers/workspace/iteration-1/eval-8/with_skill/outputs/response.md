# Custom IServerSideSessionStore with Redis

Here's how to register a custom `IServerSideSessionStore` implementation backed by Redis, showing both the one-step and two-step registration patterns.

## Registration Patterns

### One-Step Registration

```csharp
// Program.cs — one-step: pass the custom store type directly
builder.Services.AddIdentityServer()
    .AddServerSideSessions<RedisSessionStore>();
```

This registers server-side sessions and your custom store in a single call.

### Two-Step Registration

```csharp
// Program.cs — two-step: enable sessions first, then register the store
builder.Services.AddIdentityServer()
    .AddServerSideSessions()
    .AddServerSideSessionStore<RedisSessionStore>();
```

This first enables the default server-side session infrastructure, then replaces the default store with your custom implementation. The two-step approach is useful when you have other chained calls between `AddServerSideSessions()` and the store registration.

## What Data Is Stored

The session stores the serialized ASP.NET Core `AuthenticationTicket`, which includes all claims and `AuthenticationProperties.Items`. The data is **protected using ASP.NET Core's Data Protection API** — your Redis store receives encrypted bytes, not plaintext.

## Queryable Indices

The session record exposes three queryable indices that are extracted from the ticket:

| Index | Source | Notes |
|-------|--------|-------|
| **SubjectId** | `sub` claim value | Always available; identifies the user |
| **SessionId** | `sid` claim value | Always available; identifies the specific session |
| **DisplayName** | Configurable claim type | **Null by default due to PII concerns** |

The `UserDisplayNameClaimType` is **unset (null) by default** because display names often contain PII (names, emails). You must explicitly opt in:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.ServerSideSessions.UserDisplayNameClaimType = "name";
}).AddServerSideSessions<RedisSessionStore>();
```

## Custom Store Implementation Skeleton

Your `RedisSessionStore` must implement `IServerSideSessionStore`:

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
        // Store the session in Redis
        // session.Key — unique identifier
        // session.SubjectId — sub claim
        // session.SessionId — sid claim
        // session.DisplayName — configurable claim (may be null)
        // session.Ticket — the serialized/protected AuthenticationTicket
        // session.Created, session.Renewed, session.Expires — timestamps
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

    public Task<GetSessionsResults> QuerySessionsAsync(SessionQuery filter, CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException();
    }

    public Task<IReadOnlyCollection<ServerSideSession>> GetAndRemoveExpiredSessionsAsync(int count, CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException();
    }
}
```

## Important Considerations

- **Data Protection keys** must be shared across all instances that access the session store (since the ticket is encrypted with Data Protection)
- The `Ticket` property on `ServerSideSession` contains the Data Protection-encrypted `AuthenticationTicket` — your store just needs to persist it as-is
- Use Redis data structures that support efficient queries by SubjectId and SessionId (e.g., secondary indices or hash sets)
