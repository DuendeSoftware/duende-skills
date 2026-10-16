# Custom (Redis) server-side session store

Implement `IServerSideSessionStore`:

```csharp
public class RedisSessionStore : IServerSideSessionStore
{
    Task<ServerSideSession?> GetSessionAsync(string key, CancellationToken ct);
    Task CreateSessionAsync(ServerSideSession session, CancellationToken ct);
    Task UpdateSessionAsync(ServerSideSession session, CancellationToken ct);
    Task DeleteSessionAsync(string key, CancellationToken ct);
    Task<IReadOnlyCollection<ServerSideSession>> GetSessionsAsync(SessionFilter filter, CancellationToken ct);
    Task DeleteSessionsAsync(SessionFilter filter, CancellationToken ct);
    Task<IReadOnlyCollection<ServerSideSession>> GetAndRemoveExpiredSessionsAsync(int count, CancellationToken ct);
    Task<QueryResult<ServerSideSession>> QuerySessionsAsync(SessionQuery? filter, CancellationToken ct);
}
```

## One-step registration

```csharp
builder.Services.AddIdentityServer()
    .AddServerSideSessions<RedisSessionStore>();
```

## Two-step registration

```csharp
builder.Services.AddSingleton<IServerSideSessionStore, RedisSessionStore>();   // or Transient/Scoped

builder.Services.AddIdentityServer()
    .AddServerSideSessions();
```

The two-step form is useful when you need custom lifetimes or factory registration for the store.

## Data stored (`ServerSideSession`)
- `Key` – unique key (primary identifier)
- `Scheme` – authentication scheme
- `SubjectId`
- `SessionId`
- `DisplayName`
- `Created`, `Renewed`, `Expires`
- `Ticket` – serialized, protected authentication ticket

## Queryable indices
Key (unique), SubjectId, SessionId, and DisplayName (supports partial/contains matching in `SessionQuery`, e.g. in EF). In Redis you'll need secondary indexes (sets/sorted sets) for subject, session id, expiry, and display-name search. Expiry can be handled with sorted sets by `Expires`.
