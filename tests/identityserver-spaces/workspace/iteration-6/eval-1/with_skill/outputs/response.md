# Multi-Issuer or something else? → Use **Spaces** (preview, licensed add-on)

Multi-Issuer only varies the `iss` value by request host. It gives **no data isolation**: clients, grants and sessions stay shared. What you describe (separate clients, grants and issuer per customer in one deployment) is exactly what **IdentityServer Spaces** provides.

| | Multi-Issuer | Tenant hint (`acr_values=tenant:x`) | Spaces |
|---|---|---|---|
| What | `iss` varies by host | Client-supplied login hint | Isolated config + operational data per tenant |
| Selected by | Request host | Client | Server, from origin/path |
| Data isolation | None | None | Yes |
| Issuer | Per host | Shared | One per space |

## How Spaces work
- A space is an isolated IdentityServer environment in one deployment: its own clients, resources, grants, sessions and issuer, but the same process, code and database infrastructure.
- Built on **Duende Storage** pools: each space maps to a pool ID in the same database (default space = pool `0`). So your in-memory stores need to move to Duende Storage.
- The server resolves the space at the start of each request (by origin and/or path) and routes all store operations to that pool.
- Clients select a space via their authority = the space's base URL (e.g. `https://acme.example.com` or `https://login.example.com/t/acme`), **not** via `acr_values`.

## Adapting your Program.cs
```csharp
builder.Services
    .AddIdentityServer()                 // leave IssuerUri unset
    .AddServerSideSessions()
    .AddStorage(s => s.AddSqlite(o => o.ConnectionString = cs))
    .AddConfigurationStorage()
    .AddOperationalStorage();

builder.Services.AddSpaces();

app.UseForwardedHeaders();
app.UseSpaceResolution();   // before UseRouting
app.UseRouting();
app.UseIdentityServer();
```
Then create one space per customer with `ISpaceAdmin` and register that customer's clients in it.

## What Spaces do NOT isolate
Signing credentials, ASP.NET Core Data Protection, external caches, telemetry, rate limits, custom services, email delivery, and user databases not using `IStorageFactory`. If "isolated" must include these, scope them per space yourself (e.g. per-space signing keys) or use separate deployments for customers with stricter requirements.

**Bottom line**: Spaces for per-customer isolation in one deployment; Multi-Issuer only if you merely need different issuers per host.
