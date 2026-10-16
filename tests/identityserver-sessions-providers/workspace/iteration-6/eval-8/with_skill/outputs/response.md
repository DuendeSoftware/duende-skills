# Custom (Redis) `IServerSideSessionStore`

Business/Enterprise edition. Implement `IServerSideSessionStore` (create/get/update/delete by key, filter by `SessionFilter`, query via `SessionQuery`, and fetch-and-remove expired sessions for the cleanup job).

## Registration

**One-step:**

```csharp
builder.Services.AddIdentityServer()
    .AddServerSideSessions<RedisSessionStore>();
```

**Two-step:**

```csharp
builder.Services.AddIdentityServer()
    .AddServerSideSessions()
    .AddServerSideSessionStore<RedisSessionStore>();
```

Order matters: `AddServerSideSessions()` must come after any custom `IRefreshTokenService` registration. Don't also call `AddOperationalStore` expecting it to be overridden. Without a custom or EF store the default is in-memory (not for production).

## What is stored
The serialized ASP.NET Core `AuthenticationTicket` (all claims plus `AuthenticationProperties.Items`), protected with Data Protection. Share Data Protection keys across instances.

## Queryable indices

| Index | Source |
|---|---|
| Subject ID | `sub` claim |
| Session ID | `sid` claim |
| Display Name | configurable claim, e.g. `options.ServerSideSessions.UserDisplayNameClaimType = "name"` (null by default for PII reasons) |

In Redis you'll need to maintain secondary indexes (e.g. sets keyed by subject id and session id, a sorted set on expiry for `GetAndRemoveExpiredSessionsAsync`, and a way to do display-name search for `QuerySessionsAsync`).

Tip: `QuerySessionsAsync` does the full-text search and is slower; for plain listing the filter-based `GetSessionsAsync` is preferred.
