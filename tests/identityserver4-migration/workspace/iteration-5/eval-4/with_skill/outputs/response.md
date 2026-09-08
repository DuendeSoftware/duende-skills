# Database migrations from IdentityServer4 v4 to Duende IdentityServer v7/v8

Both EF Core stores change schema between IdentityServer4 v4 and Duende IdentityServer, so you create a migration for **each** DbContext and then apply them.

## Create the migrations

Run these against the assembly that holds your migrations (the same `MigrationsAssembly` configured in `Startup.cs`):

```bash
# Operational store (PersistedGrantDbContext)
dotnet ef migrations add UpdateToDuende -c PersistedGrantDbContext \
    -o Data/Migrations/IdentityServer/PersistedGrantDb

# Configuration store (ConfigurationDbContext)
dotnet ef migrations add UpdateToDuende -c ConfigurationDbContext \
    -o Data/Migrations/IdentityServer/ConfigurationDb
```

## Apply the migrations

```bash
dotnet ef database update -c PersistedGrantDbContext
dotnet ef database update -c ConfigurationDbContext
```

(You already run `Database.Migrate()` for both contexts at startup in `Program.cs`, so applied migrations will also flow through on boot.)

## What's new in the Duende schema vs. IdentityServer4 v4

**Operational store (`PersistedGrantDbContext`):**

| New table / column | Purpose |
|--------------------|---------|
| **`Keys`** | Storage for **automatic key management** — Duende creates and rotates signing keys and persists them here (this replaces `AddDeveloperSigningCredential`) |
| **`ServerSideSessions`** | Server-side session management (new in Duende) |
| **`PushedAuthorizationRequests`** | PAR (Pushed Authorization Request) support |
| `ConsumedTime` index on `PersistedGrants` | Performance optimization |

**Configuration store (`ConfigurationDbContext`):**

| New table / column | Purpose |
|--------------------|---------|
| **`IdentityProviders`** | Configuration for **dynamic OIDC identity providers** managed at runtime |
| `RequireResourceIndicator` on `ApiResources` | Resource indicator support |
| Timestamp columns / unique constraints | Created/updated tracking and duplicate prevention |

**New client columns (on the `Clients` table):**

- `InitiateLoginUri` — third-party initiated login
- **`RequireDPoP`**, `DPoPValidationMode`, `DPoPClockSkew` — **DPoP** (Demonstrating Proof-of-Possession) enforcement
- **`RequirePushedAuthorization`**, `PushedAuthorizationLifetime` — require **PAR** for the client

## Important cautions

- **Review the generated migrations before applying them.** For a straight v4 → Duende jump the changes are additive, but always inspect the scaffolded migration so nothing unexpected drops a table.
- **`RedirectUri` column length** was reduced from 2000 to 400 characters. This is safe unless you use redirect URIs longer than 400 characters (extremely rare).
- If you were on IdentityServer4 **v3** rather than v4, the `ApiResource`/`ApiScope` restructuring requires custom delta SQL first to avoid data loss — that's a separate v3→v4 step.
