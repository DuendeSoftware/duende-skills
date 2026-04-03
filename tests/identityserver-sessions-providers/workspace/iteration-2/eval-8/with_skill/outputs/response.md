# Custom IServerSideSessionStore with Redis

Duende IdentityServer supports replacing the default Entity Framework Core session store with your own implementation of `IServerSideSessionStore`. There are two registration patterns available.

## Registration Patterns

### One-Step Registration

The simplest approach is the single generic overload that both enables server-side sessions and registers your custom store in one call:

```csharp
// Program.cs
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(/* ... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryClients(/* ... */)
    .AddServerSideSessions<RedisSessionStore>();
```

### Two-Step Registration

Alternatively, you can enable server-side sessions first and then register the custom store separately. This is useful when you have additional configuration or middleware between the two steps:

```csharp
// Program.cs
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(/* ... */)
    .AddInMemoryApiScopes(/* ... */)
    .AddInMemoryClients(/* ... */)
    .AddServerSideSessions()
    .AddServerSideSessionStore<RedisSessionStore>();
```

Both approaches register `RedisSessionStore` as the `IServerSideSessionStore` implementation in the DI container.

## What Data Is Stored in the Session

Each server-side session contains the **serialized ASP.NET Core `AuthenticationTicket`**, which includes all user claims and the `AuthenticationProperties.Items` dictionary. This data is **protected using ASP.NET Core's Data Protection API**, so your Redis store will hold an opaque, encrypted byte payload. You must ensure that Data Protection keys are persisted and shared across all load-balanced instances so that any node can unprotect sessions created by another.

## Queryable Indices

The session store exposes three queryable indices extracted from the authentication ticket:

| Index            | Source                                            |
| ---------------- | ------------------------------------------------- |
| **SubjectId**    | Value of the `sub` claim                          |
| **SessionId**    | Value of the `sid` claim                          |
| **DisplayName**  | Configurable claim type (e.g., `name` or `email`) |

These indices allow filtering and querying through `ISessionManagementService` methods like `QuerySessionsAsync` and `GetSessionsAsync`.

**Important**: The `UserDisplayNameClaimType` option is **null by default** due to PII concerns. If you don't explicitly set it, the `DisplayName` index will not be populated. To store display names, configure the claim type:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.ServerSideSessions.UserDisplayNameClaimType = "name";
}).AddServerSideSessions<RedisSessionStore>();
```

## Skeleton Redis Store Implementation

Here's a starting point for your `IServerSideSessionStore` implementation:

```csharp
using Duende.IdentityServer.Models;
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
        // Store session keyed by session.Key
        // Index by session.SubjectId, session.SessionId, session.DisplayName
        throw new NotImplementedException();
    }

    public Task<ServerSideSession?> GetSessionAsync(string key, CancellationToken cancellationToken = default)
    {
        // Retrieve session by its unique key
        throw new NotImplementedException();
    }

    public Task UpdateSessionAsync(ServerSideSession session, CancellationToken cancellationToken = default)
    {
        // Update the existing session entry
        throw new NotImplementedException();
    }

    public Task DeleteSessionAsync(string key, CancellationToken cancellationToken = default)
    {
        // Remove a session by its key
        throw new NotImplementedException();
    }

    public Task<IReadOnlyCollection<ServerSideSession>> GetSessionsAsync(SessionFilter filter, CancellationToken cancellationToken = default)
    {
        // Query by SubjectId, SessionId, etc.
        throw new NotImplementedException();
    }

    public Task DeleteSessionsAsync(SessionFilter filter, CancellationToken cancellationToken = default)
    {
        // Bulk delete by SubjectId, SessionId, etc.
        throw new NotImplementedException();
    }

    public Task<GetSessionsResult> GetAndRemoveExpiredSessionsAsync(int count, CancellationToken cancellationToken = default)
    {
        // Used by the cleanup job — return and remove up to `count` expired sessions
        throw new NotImplementedException();
    }

    public Task<QueryResult<ServerSideSession>> QuerySessionsAsync(SessionQuery filter = null, CancellationToken cancellationToken = default)
    {
        // Paged query supporting ResultsToken for continuation
        throw new NotImplementedException();
    }
}
```

Your Redis implementation should maintain secondary indices (e.g., Redis sorted sets or hash sets keyed by `SubjectId` and `SessionId`) so that the query and filter operations perform efficiently.
