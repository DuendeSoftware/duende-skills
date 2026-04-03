# Database Migrations: IdentityServer4 v4 → Duende IdentityServer v7

## Creating the Migrations

Create EF Core migrations for both contexts:

```bash
dotnet ef migrations add UpdateToDuende_v7 -c PersistedGrantDbContext \
    -o Data/Migrations/IdentityServer/PersistedGrantDb

dotnet ef migrations add UpdateToDuende_v7 -c ConfigurationDbContext \
    -o Data/Migrations/IdentityServer/ConfigurationDb
```

Apply them:

```bash
dotnet ef database update -c PersistedGrantDbContext
dotnet ef database update -c ConfigurationDbContext
```

## New Tables and Columns

### PersistedGrantDbContext (Operational Store)

| Change | Purpose |
|--------|---------|
| **`Keys` table** (new) | Automatic key management — stores signing/validation keys |
| **`ServerSideSessions` table** (new) | Server-side session management |
| **`PushedAuthorizationRequests` table** (new) | PAR (Pushed Authorization Requests) support |
| `ConsumedTime` index on `PersistedGrants` | Performance optimization for grant cleanup |

### ConfigurationDbContext (Configuration Store)

| Change | Purpose |
|--------|---------|
| **`IdentityProviders` table** (new) | Dynamic OIDC provider configuration |
| `RequireResourceIndicator` column on `ApiResources` | Resource indicator support (RFC 8707) |
| Timestamp columns on entities | Created, updated, last accessed tracking |
| Unique constraints on child tables | Prevent duplicate entries |

### Client Table Changes

| Column | Purpose |
|--------|---------|
| `InitiateLoginUri` | Third-party initiated login |
| **`RequireDPoP`**, `DPoPValidationMode`, `DPoPClockSkew` | DPoP enforcement per client |
| **`RequirePushedAuthorization`**, `PushedAuthorizationLifetime` | PAR requirement per client |

## Important Notes

- The `RedirectUri` column length was reduced from 2000 to 400 characters. This is safe unless you have unusually long redirect URIs.
- Review the generated migration code before applying — ensure no unintended table drops or data-losing operations exist.
- If migrating from v3, the ConfigurationDbContext migration is more complex due to table renames (see v3 → v4 migration guidance separately).
