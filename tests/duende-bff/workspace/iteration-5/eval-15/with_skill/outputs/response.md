# Where tokens live with BFF server-side sessions — and the in-memory store question

## Where the tokens live: on the server, not in the cookie

With **server-side sessions**, the browser cookie carries **only a session id** — an opaque key. It does **not** contain any tokens or claims.

**All tokens live in the server-side session store**, including:

- the **access token**,
- the **ID token**, and
- crucially, the **refresh token**.

This is exactly why server-side sessions are a security win: the refresh token (the most sensitive, longest-lived credential) never leaves the server and is never encrypted-into-a-cookie sitting in the browser. It also keeps the cookie tiny and lets you revoke a session server-side.

(By contrast, the default cookie-based session encrypts the claims and tokens **into the cookie** itself via Data Protection.)

## Is the in-memory server-side store OK for a 3-node cluster? No.

The in-memory server-side session store is **not suitable** for your 3-node production deployment, for two reasons:

1. **Not durable** — it lives in process memory, so every session is **lost on restart/redeploy**. All users are logged out on each deploy.
2. **Not shared** — each node has its own memory. A user whose session was created on node A but whose next request is load-balanced to node B **won't be found** — node B has no record of that session id, so the user **appears logged out**. With 3 nodes that happens on roughly 2 out of 3 requests.

So `AddServerSideSessions()` alone (in-memory) gives you the worst of both worlds in a cluster: random logouts plus loss on restart.

## What to use instead: a persistent, shared store

For any multi-node BFF, use a **persistent, shared** session store so every node reads and writes the same sessions. Duende provides the EF Core–backed store in **`Duende.BFF.EntityFramework`** via **`AddEntityFrameworkServerSideSessions`**:

```csharp
// dotnet add package Duende.BFF.EntityFramework
builder.Services.AddBff()
    .AddEntityFrameworkServerSideSessions(options =>
    {
        options.UseSqlServer(builder.Configuration.GetConnectionString("BffSessions"));
    });
```

Point all three nodes at the same database and they share one session store — no random logouts, and sessions survive restarts.

> Also remember: sharing sessions solves session lookup, but you must **also** configure a shared **Data Protection** key ring across the nodes so the session cookie itself can be decrypted by every instance. The two together are what make a load-balanced BFF stable.

## Summary

- **Cookie:** session id only.
- **Server-side store:** all tokens, including the refresh token.
- **In-memory store:** not durable, not shared → unsuitable for 3 nodes.
- **Use:** a persistent shared store — `AddEntityFrameworkServerSideSessions` from `Duende.BFF.EntityFramework` (plus shared Data Protection keys).
