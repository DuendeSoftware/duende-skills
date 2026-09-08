Scaling IdentityServer to 3 replicas in Aspire is easy to declare, but IdentityServer is stateful in ways that matter once more than one instance is running behind a load balancer. Here's the AppHost code plus the shared-state you must set up first.

## AppHost code

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sql = builder.AddSqlServer("sql");
var identityDb = sql.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sql)
    .WithReplicas(3);

builder.Build().Run();
```

`.WithReplicas(3)` runs three copies of the process; Aspire load-balances requests across them.

## Why replicas need shared state

Because any request can hit any instance, the three replicas must agree on all security-sensitive state:

- **Signing keys must be shared.** Tokens are signed with a private key and validated against the public key from the JWKS endpoint. If each replica has its own key, a token minted by one instance will fail validation against another instance's published keys. Use a shared signing-key store (persisted in the database) rather than per-instance keys.

- **ASP.NET Core Data Protection keys must be shared.** Data Protection protects auth cookies and OIDC correlation/nonce values. By default each instance generates its own key ring in a local folder, so a cookie written by replica A can't be read by replica B. Point all replicas at a shared key ring (database, Redis, or blob storage) with `PersistKeysTo...` and, ideally, a fixed application name.

- **Persisted grants / sessions must be shared.** Authorization codes, refresh/reference tokens, device codes, and server-side sessions have to be stored centrally (the shared SQL database) so any replica can honor a flow another replica started.

- **Use a distributed cache** (e.g. Redis) if you rely on any cross-request caching so it's consistent across instances.

## Pitfalls to avoid

> Don't turn on `WithReplicas(3)` while still using the development defaults. **In-memory stores and file/developer signing credentials do not work across replicas** — you'll get sporadic `IDX10501`/signature-validation errors, "unable to unprotect the message" cookie failures, and lost login sessions as traffic moves between instances. Move signing keys, Data Protection, and grant/session storage to shared persistent backends first, then scale out.
