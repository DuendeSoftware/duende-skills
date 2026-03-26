# Database Migrations: IdentityServer4 to Duende IdentityServer v7

## Creating and Applying Migrations

After updating your NuGet packages and namespaces, create EF Core migrations for both database contexts:

```bash
# Migration for the operational store (persisted grants, device codes, keys, sessions)
dotnet ef migrations add UpdateToDuende_v7 -c PersistedGrantDbContext \
    -o Data/Migrations/IdentityServer/PersistedGrantDb

# Migration for the configuration store (clients, resources, scopes, identity providers)
dotnet ef migrations add UpdateToDuende_v7 -c ConfigurationDbContext \
    -o Data/Migrations/IdentityServer/ConfigurationDb
```

Apply the migrations:

```bash
dotnet ef database update -c PersistedGrantDbContext
dotnet ef database update -c ConfigurationDbContext
```

## New Tables in Duende IdentityServer v7

### Operational Store (PersistedGrantDbContext)

| New Table | Purpose |
|-----------|---------|
| **`Keys`** | Stores signing keys for **automatic key management**. Duende automatically creates, rotates, and retires signing keys — this table persists them across restarts and instances. |
| **`ServerSideSessions`** | Stores **server-side session** data. Enables session management, querying active sessions, and coordinating logout across clients. |
| **`PushedAuthorizationRequests`** | Stores **Pushed Authorization Requests (PAR)**. Clients push authorization parameters to this endpoint before redirecting the user, improving security by keeping parameters server-side. |

### Configuration Store (ConfigurationDbContext)

| New Table | Purpose |
|-----------|---------|
| **`IdentityProviders`** | Stores **dynamic OIDC provider** configuration. Allows adding/removing external identity providers at runtime without redeploying. |

## New Client Columns

Several new columns on the `Clients` table support advanced security features:

| Column | Purpose |
|--------|---------|
| `RequireDPoP` | Enforces **Demonstrating Proof-of-Possession (DPoP)** for this client — tokens are bound to the client's key pair |
| `DPoPValidationMode` | Controls DPoP validation strictness |
| `DPoPClockSkew` | Allowed clock skew for DPoP proof timestamps |
| `RequirePushedAuthorization` | Requires this client to use **PAR** (Pushed Authorization Requests) |
| `PushedAuthorizationLifetime` | How long a pushed authorization request remains valid |
| `InitiateLoginUri` | URI for third-party initiated login |

## Additional Schema Changes

- **`RequireResourceIndicator`** column on `ApiResources` — supports RFC 8707 resource indicators
- **Timestamp columns** added to many entities (Created, Updated, LastAccessed) for auditing
- **Unique constraints** added to child tables to prevent duplicate entries
- **`ConsumedTime` index** on `PersistedGrants` for performance optimization
- **`RedirectUri` column length** reduced from 2000 to 400 characters (safe unless you have extremely long redirect URIs)

## Important Notes

- These migrations are safe for the v4 → Duende path (unlike the v3 → v4 migration which requires custom SQL scripts to avoid data loss)
- Review the generated migration code before applying — verify it does not drop existing tables or columns
- If you have a multi-instance deployment, apply migrations once to a shared database before deploying updated code
