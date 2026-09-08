# Custom `IServerSideSessionStore` (Redis)

You replace the default EF Core session store by implementing `IServerSideSessionStore` and registering your Redis-backed type. There are two equivalent registration styles.

## Registration patterns

### One-step

```csharp
builder.Services.AddIdentityServer()
    .AddServerSideSessions<RedisSessionStore>();
```

### Two-step

```csharp
builder.Services.AddIdentityServer()
    .AddServerSideSessions()                        // enable server-side sessions
    .AddServerSideSessionStore<RedisSessionStore>(); // then swap in your store
```

Both wire `RedisSessionStore` in as the `IServerSideSessionStore`. Use whichever reads better; the two-step form is handy when other builder calls sit between enabling sessions and choosing the store.

> **Registration order:** if you also register a custom `IRefreshTokenService`, do it *before* `AddServerSideSessions()`.

## Store skeleton

```csharp
using Duende.IdentityServer.Stores;
using Duende.IdentityServer.Models;

public class RedisSessionStore : IServerSideSessionStore
{
    public Task CreateSessionAsync(ServerSideSession session, CancellationToken ct = default) { /* ... */ }
    public Task<ServerSideSession?> GetSessionAsync(string key, CancellationToken ct = default) { /* ... */ }
    public Task UpdateSessionAsync(ServerSideSession session, CancellationToken ct = default) { /* ... */ }
    public Task DeleteSessionAsync(string key, CancellationToken ct = default) { /* ... */ }

    // Queryable by the indexed fields:
    public Task<IReadOnlyCollection<ServerSideSession>> GetSessionsAsync(SessionFilter filter, CancellationToken ct = default) { /* ... */ }
    public Task<IReadOnlyCollection<ServerSideSession>> GetAndRemoveExpiredSessionsAsync(int count, CancellationToken ct = default) { /* ... */ }
    public Task DeleteSessionsAsync(SessionFilter filter, CancellationToken ct = default) { /* ... */ }
    public Task<QueryResult<ServerSideSession>> QuerySessionsAsync(SessionQuery? filter = null, CancellationToken ct = default) { /* ... */ }
}
```

## What is stored in a session

Each `ServerSideSession` holds the serialized ASP.NET Core **`AuthenticationTicket`** — all of the user's claims plus the `AuthenticationProperties.Items`. That ticket is **protected using ASP.NET Core's Data Protection API** before it is written to your store, so in Redis you're persisting an opaque, encrypted `Data` blob (not plaintext claims). Your store just needs to save/return that blob; IdentityServer handles protect/unprotect.

> Because Data Protection is involved, in a multi-node deployment you must persist and **share the Data Protection keys** across instances, or tickets written by one node won't decrypt on another.

## Queryable indices

Alongside the protected blob, three fields are extracted from the ticket and stored as **queryable indices** so admin tooling and cleanup can find sessions:

| Index | Source |
| --- | --- |
| **SubjectId** | the `sub` claim |
| **SessionId** | the `sid` claim |
| **DisplayName** | a configurable claim type (e.g. `name` or `email`) |

Your Redis implementation should index on these (e.g. secondary keys / sets keyed by `sub` and `sid`) so `GetSessionsAsync` / `QuerySessionsAsync` can filter efficiently.

**Important about DisplayName:** `options.ServerSideSessions.UserDisplayNameClaimType` is **`null` (unset) by default**, deliberately, because a display name is PII and shouldn't be indexed unless you opt in. If you want the DisplayName index populated you must set it explicitly:

```csharp
builder.Services.AddIdentityServer(o =>
    o.ServerSideSessions.UserDisplayNameClaimType = "name");
```

When it's null, the DisplayName index is simply empty and you can only query by `sub` / `sid`.
