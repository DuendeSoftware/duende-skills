# Registering a Custom `IServerSideSessionStore` (Redis)

To back server-side sessions with Redis instead of EF Core, implement `IServerSideSessionStore` and register your type with IdentityServer. There are two registration approaches.

## One-step registration

Pass your store type directly to `AddServerSideSessions`:

```csharp
builder.Services.AddIdentityServer()
    .AddServerSideSessions<RedisSessionStore>();
```

## Two-step registration

Enable server-side sessions, then register the store separately:

```csharp
builder.Services.AddIdentityServer()
    .AddServerSideSessions()
    .AddServerSideSessionStore<RedisSessionStore>();
```

Both result in `RedisSessionStore` being used as the `IServerSideSessionStore`.

## Store implementation shape

```csharp
using Duende.IdentityServer.Stores;
using Duende.IdentityServer.Models;

public class RedisSessionStore : IServerSideSessionStore
{
    public Task CreateSessionAsync(ServerSideSession session, CancellationToken ct = default) => /* ... */;
    public Task<ServerSideSession?> GetSessionAsync(string key, CancellationToken ct = default) => /* ... */;
    public Task UpdateSessionAsync(ServerSideSession session, CancellationToken ct = default) => /* ... */;
    public Task DeleteSessionAsync(string key, CancellationToken ct = default) => /* ... */;
    public Task<IReadOnlyCollection<ServerSideSession>> GetSessionsAsync(SessionFilter filter, CancellationToken ct = default) => /* ... */;
    public Task<QueryResult<ServerSideSession>> QuerySessionsAsync(SessionQuery? filter = null, CancellationToken ct = default) => /* ... */;
    // plus expired-session cleanup methods
}
```

## What is stored

Each session persists the serialized ASP.NET Core **`AuthenticationTicket`** (the user's claims and authentication properties). IdentityServer protects this data using ASP.NET Core **Data Protection**, so what you store in Redis is an encrypted blob rather than plaintext.

Because Data Protection is used, make sure the Data Protection keys are shared/persisted across all instances in a load-balanced setup, otherwise sessions written by one node cannot be read by another.

## Queryable indices

To support admin queries and cleanup, the store exposes a few indexed fields extracted from the ticket:

- **SubjectId** — from the `sub` claim
- **SessionId** — from the `sid` claim
- **DisplayName** — from a configurable claim type (e.g. `name`)

Your Redis store should maintain secondary indexes (for example Redis sets keyed by subject id and session id) so it can answer `GetSessionsAsync`/`QuerySessionsAsync` filters efficiently. The display name claim type used for the index is configurable via `options.ServerSideSessions.UserDisplayNameClaimType`.
