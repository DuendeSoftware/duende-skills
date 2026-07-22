# Deploying IdentityServer with SAML on Multiple Nodes Behind a Load Balancer

## The Core Problem

SAML SSO and SLO flows are stateful. IdentityServer stores intermediate request/session data in-process by default. When you have multiple nodes behind a load balancer and requests can land on any node:

- A user's SAML AuthnRequest state is stored on Node A
- The authentication callback arrives on Node B
- Node B has no state → the SSO flow fails

The same problem affects SLO: the logout session tracking state must be shared across all nodes.

You **must** replace the default in-memory state stores with distributed implementations.

---

## Required: Distributed State Stores

### 1. `ISamlSigninStateStore` — Sign-in Request State

Tracks the pending SAML AuthnRequest while the user authenticates. Without a distributed implementation, multi-node deployments will see broken SSO flows.

**EF Core (recommended — auto-registered via operational store):**

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    // ...
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });
```

> When you call `AddOperationalStore()`, IdentityServer automatically registers EF Core implementations of **both** `ISamlSigninStateStore` and `ISamlLogoutSessionStore`. No additional registration is needed.

**Custom Redis implementation (example):**

```csharp
builder.Services.AddTransient<ISamlSigninStateStore, RedisSamlSigninStateStore>();

public class RedisSamlSigninStateStore : ISamlSigninStateStore
{
    private readonly IDatabase _redis;

    public RedisSamlSigninStateStore(IConnectionMultiplexer mux)
        => _redis = mux.GetDatabase();

    public async Task<SamlSigninRequestState?> GetSigninRequestStateAsync(
        string stateId, CancellationToken ct)
    {
        var json = await _redis.StringGetAsync(stateId);
        return json.IsNull ? null : JsonSerializer.Deserialize<SamlSigninRequestState>(json!);
    }

    public async Task StoreSigninRequestStateAsync(
        SamlSigninRequestState state, CancellationToken ct)
    {
        var json = JsonSerializer.Serialize(state);
        await _redis.StringSetAsync(state.Id, json,
            expiry: TimeSpan.FromMinutes(15)); // match SamlOptions.SigninStateLifetime
    }

    public async Task UpdateSigninRequestStateAsync(
        SamlSigninRequestState state, CancellationToken ct)
    {
        // Same as store — update the value in Redis
        await StoreSigninRequestStateAsync(state, ct);
    }

    public async Task RemoveSigninRequestStateAsync(
        string stateId, CancellationToken ct)
        => await _redis.KeyDeleteAsync(stateId);
}
```

### 2. `ISamlLogoutSessionStore` — SLO Session Tracking

Tracks which SPs have active sessions and their logout responses during SLO. Required for correct multi-SP logout coordination.

`SamlLogoutSession` has these relevant properties:
- `SkippedSpCount` (int) — number of SPs that did not respond
- `ExpiresAtUtc` (DateTime) — when this session record expires
- `ExpectedResponses` (dictionary) — maps SP entity IDs to response state

The key method is `TryRecordResponseAsync(string requestId, string issuer, bool success, CancellationToken ct)`.

**EF Core (auto-registered with operational store — see above).**

**Custom implementation skeleton:**

```csharp
builder.Services.AddTransient<ISamlLogoutSessionStore, RedisSamlLogoutSessionStore>();
```

---

## Required: Data Protection Key Distribution

IdentityServer uses ASP.NET Core Data Protection to protect SAML state cookies and tokens. In a multi-node deployment, all nodes must share the same key ring — otherwise a state cookie written on Node A cannot be read on Node B.

```csharp
// Store keys in a shared location — SQL Server example
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<YourDbContext>()     // or PersistKeysToAzureBlobStorage(...)
    .SetApplicationName("your-identityserver"); // must be identical on ALL nodes
```

Other supported backends:
- `PersistKeysToAzureBlobStorage(...)` — Azure Blob Storage
- `PersistKeysToStackExchangeRedis(...)` — Redis
- `PersistKeysToFileSystem(new DirectoryInfo("/shared/keys"))` — Shared NFS/SMB mount

> **Without shared Data Protection keys, SSO will fail** even if you have distributed SAML stores, because the state cookie protecting the SAML sign-in state cannot be decrypted on a different node.

---

## Required: Signing Certificate Consistency

All nodes must use the **same** signing certificate. Do not let each node generate its own self-signed certificate. Options:

- Load from a shared Azure Key Vault
- Load from a certificate store on all nodes (identical thumbprint)
- Mount the same PFX file via a Kubernetes Secret or volume

```csharp
builder.Services.AddIdentityServer()
    .AddSigningCredential(LoadCertificateFromKeyVault()); // same cert on all nodes
```

---

## Recommended: Configure Lifetime Parameters

Tune `SamlOptions` so that state lifetimes are sufficient for your load balancer's connection drain time:

```csharp
builder.Services.AddIdentityServer()
    .AddSaml(saml =>
    {
        // How long a pending sign-in state is retained
        // Set to cover round-trip time including any user interaction
        saml.SigninStateLifetime = TimeSpan.FromMinutes(15);

        // How long the SLO session tracking state is retained
        saml.LogoutSessionLifetime = TimeSpan.FromMinutes(5);

        // Clock skew — increase if nodes have slight time drift
        saml.DefaultClockSkew = TimeSpan.FromMinutes(5);
    });
```

---

## Summary Checklist

| Concern | Solution |
|---|---|
| SSO state lost across nodes | Use `AddOperationalStore()` (EF Core) or implement `ISamlSigninStateStore` with Redis/other |
| SLO session lost across nodes | Use `AddOperationalStore()` (EF Core) or implement `ISamlLogoutSessionStore` |
| State cookies unreadable on other nodes | Configure shared Data Protection key ring (`PersistKeysToDbContext`, Redis, Azure Blob, etc.) |
| Different signing certs per node | Load the same cert from Key Vault, shared cert store, or Kubernetes Secret |
| "Response not yet valid" errors | Ensure NTP sync across nodes; increase `DefaultClockSkew` if needed |
| SP metadata cached per-node | Fine for read-only metadata; use `AddSamlServiceProviderStoreCache<T>()` backed by a shared cache |

---

## Anti-Patterns to Avoid

- ❌ Using `AddInMemorySamlServiceProviders` in production — acceptable only for development
- ❌ Omitting Data Protection key sharing — silent failures on cross-node requests
- ❌ Generating self-signed certs per-node — SPs will reject signatures from the "wrong" cert
- ❌ Setting `SigninStateLifetime` shorter than your auth flow duration — state will expire mid-flow

---

## Minimal Multi-Node `Program.cs` Skeleton

```csharp
var builder = WebApplication.CreateBuilder(args);
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")!;

// Shared Data Protection
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<ApplicationDbContext>()
    .SetApplicationName("my-identityserver");

builder.Services.AddIdentityServer()
    .AddSigningCredential(LoadCertificate())           // same cert on all nodes
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddConfigurationStore(opt =>                      // SP config from DB
    {
        opt.ConfigureDbContext = b => b.UseSqlServer(connectionString);
    })
    .AddOperationalStore(opt =>                        // distributed SSO/SLO state
    {
        opt.ConfigureDbContext = b => b.UseSqlServer(connectionString);
        opt.EnableTokenCleanup = true;
    })
    .AddSaml(saml =>
    {
        saml.SigninStateLifetime = TimeSpan.FromMinutes(15);
        saml.LogoutSessionLifetime = TimeSpan.FromMinutes(5);
        saml.DefaultClockSkew = TimeSpan.FromMinutes(5);
    });
    // ISamlSigninStateStore and ISamlLogoutSessionStore are auto-registered by AddOperationalStore()
```
