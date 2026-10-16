## Database migrations

Create and apply EF Core migrations for **both** contexts (back up first, test on a copy, review generated SQL):

```bash
dotnet ef migrations add UpdateToDuende -c PersistedGrantDbContext \
    -o Data/Migrations/IdentityServer/PersistedGrantDb
dotnet ef migrations add UpdateToDuende -c ConfigurationDbContext \
    -o Data/Migrations/IdentityServer/ConfigurationDb

dotnet ef database update -c PersistedGrantDbContext
dotnet ef database update -c ConfigurationDbContext
```

This assumes you're already on IdentityServer4 v4.x. (From v3 you'd first need the v3→v4 migration with custom delta SQL, since the auto-generated one drops and recreates tables — table renames like `ApiClaims`→`ApiResourceClaims`, and `ApiResourceScopes` join table.)

### New tables and columns vs. IdentityServer4 v4

| Context | Change | Purpose |
|---|---|---|
| Operational | `Keys` (new) | Automatic key management |
| Operational | `ServerSideSessions` (new) | Server-side sessions |
| Operational | `PushedAuthorizationRequests` (new) | PAR |
| Operational | index on `ConsumedTime` in `PersistedGrants` | Performance |
| Configuration | `IdentityProviders` (new) | Dynamic OIDC providers |
| Configuration | `RequireResourceIndicator` on `ApiResources` | Resource indicators |
| Configuration | Timestamp columns (created, updated, last accessed) | Tracking |
| Configuration | Unique constraints on child tables | Prevent duplicates |
| Client | `InitiateLoginUri` | Third-party initiated login |
| Client | `RequireDPoP`, `DPoPValidationMode`, `DPoPClockSkew` | DPoP |
| Client | `RequirePushedAuthorization`, `PushedAuthorizationLifetime` | PAR |

With v8 there are additionally `SamlSignInStates`, `SamlLogoutSessions` (operational) and `SamlServiceProviders` (configuration) for the built-in SAML support.

**Note**: the `RedirectUri` column length was reduced from 2000 to 400 characters — safe unless you have redirect URIs longer than 400 chars.
