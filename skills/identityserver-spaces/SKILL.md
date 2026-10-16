---
name: identityserver-spaces
description: "IdentityServer Spaces (preview, licensed add-on) for multi-tenancy: isolated configuration and operational data per space using Duende Storage pools, Duende.Spaces setup, ISpaceAdmin, origin/path space resolution, FallbackToDefault, IssuerUri constraints, what Spaces do not isolate, and how Spaces differ from Multi-Issuer and tenant acr_values hints."
invocable: false
---

# IdentityServer Spaces (Preview)

## When to Use This Skill

- Hosting multiple isolated security domains (SaaS tenants, regions, business units) in one IdentityServer deployment
- Installing/configuring `Duende.Spaces`, creating spaces with `ISpaceAdmin`, choosing origin vs path matching
- Deciding between Spaces, Multi-Issuer and the `tenant:` acr hint
- Reviewing what Spaces do and do not isolate

## Core Principles

- A **space** is an isolated IdentityServer environment inside one deployment: own configuration + operational data (own clients, resources, grants, sessions, issuer), same process/code/database infrastructure. **Licensed add-on; preview.**
- Built on **Duende Storage** pools: each space maps to a storage pool (numeric pool ID) in the same database. The **default space uses data pool `0`**; configured spaces normally use positive IDs. A separate reserved **management pool** stores space definitions (match rules + assigned pool); normal requests never use it as data pool. Spaces require Duende Storage (see `identityserver-duende-storage`).
- IdentityServer resolves the space at the start of each request and routes all store operations to that pool.
- Docs: https://docs.duendesoftware.com/identityserver/spaces/

## Spaces vs Multi-Issuer vs Tenant Hint

| | Multi-Issuer | Tenant hint (`acr_values=tenant:x`) | Spaces |
|---|---|---|---|
| What | `iss` varies by host (built in, no add-on) | Client-supplied login hint | Isolated config + operational data per tenant |
| Selected by | Request host | Client, per authorize request | Server, from origin/path |
| Trust | - | Untrusted | Validated against configured match patterns |
| Data isolation | None | None | Yes |
| Issuer | Per host | Shared | One per space |

A client **cannot** select a space via `acr_values`. To target a space, set the client authority to the space's base URL (= its issuer), e.g. `https://acme.example.com` (origin) or `https://login.example.com/t/acme` (path). Inside a space the tenant hint still works for sub-tenants; prefer `ISpaceContextAccessor` over trusting a hint when the space already identifies the tenant.

## Setup

```bash
dotnet add package Duende.IdentityServer --prerelease
dotnet add package Duende.Storage.Sqlite --prerelease
dotnet add package Duende.Spaces --prerelease
```

```csharp
// Program.cs
builder.Services
    .AddIdentityServer()
    .AddServerSideSessions()
    .AddStorage(storage => storage.AddSqlite(o => o.ConnectionString = connectionString))
    .AddConfigurationStorage()
    .AddOperationalStorage();

builder.Services.AddSpaces();
builder.Services.Configure<SpacesOptions>(options =>
{
    options.SpacePathPrefix = "/t";        // default
    options.FallbackToDefault = false;     // default
});
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedHost | ForwardedHeaders.XForwardedProto;
    options.KnownProxies.Add(IPAddress.Parse("203.0.113.42"));
    options.ForwardLimit = 1;
});

var app = builder.Build();
await app.Services.GetRequiredService<IStorageInstanceSchema>().MigrateAsync(CancellationToken.None);

app.UseForwardedHeaders();   // BEFORE space resolution: resolver must see public scheme/host
app.UseSpaceResolution();    // BEFORE UseRouting: path matches rewrite PathBase/Path
app.UseRouting();
app.UseIdentityServer();
```

Middleware placed after `UseSpaceResolution` can use `ISpaceContextAccessor.GetSpaceId()`.

## Creating Spaces

Use `ISpaceAdmin` from a trusted provisioning/admin path. Make it **idempotent**: query by name first, run from one deployment process (avoid query/create races).

```csharp
var spaces = app.Services.GetRequiredService<ISpaceAdmin>();
var existing = await spaces.QueryAsync(
    QueryRequest.Create<SpaceFilter, SpaceSortField>(new SpaceFilter { Name = "Acme" }), ct);

if (!existing.Items.Any(s => string.Equals(s.Name, "Acme", StringComparison.Ordinal)))
{
    var result = await spaces.CreateAsync(new CreateSpaceConfiguration
    {
        Name = "Acme",
        MatchPatterns = [ new SpaceMatchPattern { Origin = "https://login.example.com", Path = "/acme" } ]
    }, ct);
    if (!result.IsSuccess) throw new InvalidOperationException($"Could not create the Acme space: {result.Errors}");
}
```

This space requires **both** origin and path to match: `https://login.example.com/t/acme/.well-known/openid-configuration` resolves to Acme's pool.

- Moving a space to another pool changes which data it sees; deleting is a **soft delete** (pool data blocked but retained; `ISpaceAdmin.UndeleteAsync` restores the space and its rules). Authorize and audit pool reassignment/deletion as security-boundary changes (break-glass).

## Resolving Requests

Match by **origin** (dedicated host; include scheme and non-default port), **path segment** (shared host; default `/t` prefix: `/acme` → `/t/acme`, middleware moves it into `PathBase`), or **both**. Origin claims take precedence so a path can't route a request away from a space that owns the host.

- Requests with the space prefix but no matching space → `404`. Other unmatched requests → `404` too, unless `FallbackToDefault = true` (serves the default space). Only enable fallback if that's an intentional isolation decision; strict 404 is safer.
- Only accept forwarded headers from known proxies: an untrusted forwarded host/proto can select a different security boundary.
- Never trust a client-supplied space identifier without the resolution middleware validating it against a configured match pattern. Authorize admins per space.

## Issuer

Spaces rely on issuer inference from request origin + path base, which gives each space its own `iss`. **Leave `IdentityServerOptions.IssuerUri` unset**: a fixed value makes every space return the same `issuer`/`iss` (data and discovery endpoints still differ). Same rule for Multi-Issuer.

## UI and Application Services

Login/consent/logout/error pages are shared and run within the resolved space (reading that space's stores). No per-space UI/branding: inject `ISpaceContextAccessor` into scoped UI services, read `SpaceId`, and load your own space settings. User databases and other services are **not** space-aware unless they use the shared `IStorageFactory`.

**Duende User Management** uses the same storage factory: profiles, authenticators, roles and groups are stored per space by default. For a shared global user directory use a deliberately separate architecture (no opt-out switch for only User Management).

## What Spaces Do NOT Isolate

Spaces isolate persisted data only. Review and decide separately for: signing credentials (shared credentials reduce cryptographic separation; scope them per space if your trust model requires), ASP.NET Core Data Protection, external caches, telemetry, rate limits, custom services, email delivery, user databases not using `IStorageFactory`.

## Multiple Storage Instances

Spaces management data and every space's pool live in the default Duende Storage instance unless categories are mapped elsewhere; with multiple instances a category resolves to its instance first, then to the space's pool in that instance's database. See `identityserver-duende-storage`.

## High Availability

Every instance must resolve the same issuer per host/space: keep proxy host names and path bases stable (see `identityserver-deployment`).

## Common Pitfalls

1. ❌ Setting `IssuerUri` → ✅ leave unset.
2. ❌ `UseSpaceResolution()` after `UseRouting()` or before `UseForwardedHeaders()` → ✅ forwarded headers → space resolution → routing.
3. ❌ `FallbackToDefault = true` by default → ✅ keep strict 404 unless intentional.
4. ❌ Trusting forwarded headers from any source → ✅ `KnownProxies`/`KnownNetworks`.
5. ❌ Assuming shared signing keys/Data Protection/caches are per-space → ✅ review explicitly.
6. ❌ Using `acr_values=tenant:` to select a space → ✅ set authority to the space URL.
7. ❌ Non-idempotent provisioning from several instances → ✅ query-then-create from one process.

## Related Skills

- `identityserver-duende-storage` — required storage layer and pools
- `identityserver-ui-flows` — tenant hints, login/logout pages
- `identityserver-deployment` — proxies, forwarded headers, HA
- `identityserver-usermanagement` — per-space user data
- `identityserver-configuration` — Multi-Issuer / issuer options
