# Database Migrations: IdentityServer4 to Duende IdentityServer v7

## Creating Migrations

After updating NuGet packages and namespaces, create EF Core migrations for both contexts:

```bash
dotnet ef migrations add UpdateToDuende_v7 -c PersistedGrantDbContext \
    -o Data/Migrations/IdentityServer/PersistedGrantDb

dotnet ef migrations add UpdateToDuende_v7 -c ConfigurationDbContext \
    -o Data/Migrations/IdentityServer/ConfigurationDb
```

Apply:

```bash
dotnet ef database update -c PersistedGrantDbContext
dotnet ef database update -c ConfigurationDbContext
```

## New Tables and Columns in Duende IdentityServer v7

### Operational Store (PersistedGrantDbContext)

| Change | Purpose |
|--------|---------|
| **`Keys` table** (new) | Automatic key management — stores signing and validation keys |
| **`ServerSideSessions` table** (new) | Server-side session management |
| **`PushedAuthorizationRequests` table** (new) | PAR (Pushed Authorization Requests) support |
| `ConsumedTime` index on `PersistedGrants` | Performance optimization |

### Configuration Store (ConfigurationDbContext)

| Change | Purpose |
|--------|---------|
| **`IdentityProviders` table** (new) | Dynamic OIDC provider configuration |
| `RequireResourceIndicator` column on `ApiResources` | Resource indicator support |
| Timestamp columns on entities | Created, updated, last accessed tracking |

### Client Configuration

New columns on `Clients`:

| Column | Purpose |
|--------|---------|
| **`RequireDPoP`** | DPoP (Demonstration of Proof-of-Possession) enforcement |
| `DPoPValidationMode`, `DPoPClockSkew` | DPoP configuration |
| **`RequirePushedAuthorization`** | PAR requirement per client |
| `PushedAuthorizationLifetime` | PAR lifetime |
| `InitiateLoginUri` | Third-party initiated login |

## Important Notes

- Review the generated migration carefully before applying to production.
- The `RedirectUri` column length was reduced from 2000 to 400 characters.
- These migrations add new tables/columns and should be non-destructive.
