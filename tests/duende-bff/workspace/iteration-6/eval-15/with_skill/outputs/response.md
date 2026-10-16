**Where tokens live:** With server-side sessions, *all* tokens — access, refresh, id — live in the server-side session store. The cookie carries only a session id. (Without server-side sessions, claims and tokens are embedded in the encrypted cookie.)

**Is in-memory OK for 3 nodes? No.** The in-memory store (`AddServerSideSessions()`) is not durable (lost on restart) and not shared — a request that hits a different node won't find the session, so users appear logged out. Use a persistent, shared store:

```csharp
builder.Services.AddBff(o => o.SessionCleanupInterval = TimeSpan.FromMinutes(10))
    .AddEntityFrameworkServerSideSessions(o => o.UseSqlServer(cs))   // Duende.BFF.EntityFramework
    .AddSessionCleanupBackgroundProcess();
```
Run `dotnet ef migrations add UserSessions -o Migrations -c SessionDbContext` and update the DB. Also share Data Protection keys across nodes (blob+Key Vault or `PersistKeysToDbContext`), as cookies and anti-forgery tokens must decrypt on every node. Since the store holds refresh tokens, treat it as security-sensitive (restrict access, encrypt at rest). A custom store can implement `IUserSessionStore`.
