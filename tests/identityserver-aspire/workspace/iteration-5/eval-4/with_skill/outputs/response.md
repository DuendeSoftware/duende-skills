Running 3 replicas of IdentityServer in Aspire is a one-liner in the AppHost — but the important work is making IdentityServer's state **shared** across all replicas. A load balancer will route requests to any instance, so every instance must behave identically.

## AppHost code

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer)
    .WithReplicas(3);

builder.Build().Run();
```

`.WithReplicas(3)` starts three instances behind Aspire's proxy/load balancer.

## Shared state requirements

For 3 replicas to work correctly, all of the following must be shared across every instance:

1. **Shared signing key store** — IdentityServer's automatic key management stores and rotates signing keys. All replicas must read/write the same keys through a shared `ISigningKeyStore` (the EF operational store or a custom implementation). If each replica has its own keys, tokens signed by one instance won't validate against the JWKS served by another.

2. **Shared ASP.NET Data Protection keys** — Data Protection encrypts auth cookies, the OIDC state/nonce, and other protected payloads. All replicas must share the same key ring (persisted to the database, Redis, or blob storage). Without this, a cookie or authorize-request encrypted by replica A can't be decrypted by replica B, producing `CryptographicException` / correlation failures during login.

3. **Shared operational store** — Persisted grants (authorization codes, refresh/reference tokens), device codes, and server-side sessions must live in a shared database so any replica can complete a flow started by another.

4. **Distributed cache** — Needed if you use the OIDC state data formatter, the JWT replay cache, or Pushed Authorization Requests (PAR), so cached state is visible to all replicas.

## What to avoid

> Do **not** use `.WithReplicas(3)` before configuring shared state. In particular, **file-based (developer) signing keys and in-memory stores will break** with multiple replicas: you'll see intermittent token-validation failures (JWKS mismatch), lost/invalid login sessions, and "unable to unprotect" authentication cookie errors as requests bounce between instances that don't share keys or data. Move signing keys, data protection, and the operational store to shared, persistent backends first — then scale out.

See `identityserver-deployment` for data protection and operational store configuration, and `identityserver-data-storage` for the EF Core store setup.
