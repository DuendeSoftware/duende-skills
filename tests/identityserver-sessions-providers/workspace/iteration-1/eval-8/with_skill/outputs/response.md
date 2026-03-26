# Custom IServerSideSessionStore with Redis

There are two patterns for registering a custom session store, plus important details about what data is stored and what indices are available.

## Registration Pattern 1: One-Step

```csharp
builder.Services.AddIdentityServer()
    .AddServerSideSessions<RedisSessionStore>();
```

This enables server-side sessions and registers your custom store in one call.

## Registration Pattern 2: Two-Step

```csharp
builder.Services.AddIdentityServer()
    .AddServerSideSessions()
    .AddServerSideSessionStore<RedisSessionStore>();
```

This first enables server-side sessions (with the default in-memory store), then replaces the store with your custom implementation.

## Implementing IServerSideSessionStore

```csharp
using Duende.IdentityServer.Stores;

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
        var data = JsonSerializer.Serialize(session);
        await db.StringSetAsync($"session:{session.Key}", data,
            session.Expires.HasValue
                ? session.Expires.Value - DateTime.UtcNow
                : null);

        // Maintain queryable indices
        await db.SetAddAsync($"sessions:sub:{session.SubjectId}", session.Key);
        await db.SetAddAsync($"sessions:sid:{session.SessionId}", session.Key);
        if (session.DisplayName != null)
            await db.SetAddAsync($"sessions:name:{session.DisplayName}", session.Key);
    }

    // ... implement other IServerSideSessionStore methods
}
```

## What Data Is Stored in a Session

The session contains the serialized ASP.NET Core `AuthenticationTicket`, which includes all claims and `AuthenticationProperties.Items`. The data is **protected using ASP.NET Core's Data Protection API** — your store receives opaque encrypted bytes.

## Queryable Indices

The store must maintain three queryable indices extracted from the session:

| Index | Source | Purpose |
|---|---|---|
| **SubjectId** | `sub` claim value | Find all sessions for a user |
| **SessionId** | `sid` claim value | Find a specific session |
| **DisplayName** | Configurable claim type | Human-readable session identification |

**Important**: `UserDisplayNameClaimType` is **null by default** due to PII concerns. If you want display names in the session index, you must explicitly configure it:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.ServerSideSessions.UserDisplayNameClaimType = "name";
});
```

Without this configuration, the `DisplayName` field on stored sessions will always be null.

## Key Considerations

- Data Protection keys must be shared across all instances that read/write sessions
- The `AuthenticationTicket` is encrypted — you cannot inspect its contents in your store
- Sessions have a `Renewed` timestamp that is updated on each activity
- The `Expires` field corresponds to the cookie lifetime configured on the IdentityServer host