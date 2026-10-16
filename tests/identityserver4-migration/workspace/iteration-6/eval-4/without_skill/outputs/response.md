## Database migrations

You must create new EF migrations for both contexts and apply them:

```bash
dotnet ef migrations add Duende_v7_Config -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef migrations add Duende_v7_Grants -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef migrations script -c ConfigurationDbContext   # review
dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```

Back up the DB first and test on a copy. If your existing schema was from IS4 v4 with the original migrations, EF will diff the model snapshot with the new model.

Changes from IS4 v4 through Duende v7 (from memory; verify by reading the generated migration):
- **Clients**: new columns such as `CoreClaimsLifetime`? no... known ones: `RequireRequestObject`, `CibaLifetime`, `PollingInterval`, `CoordinateLifetimeWithUserSession`, `InitiateLoginUri`, `DPoP` related (`RequireDPoP`, `DPoPValidationMode`, `DPoPClockSkew`), `PushedAuthorizationLifetime`, `RequirePushedAuthorization`, `Description`, `Created`, `Updated`, etc.
- **ApiResources**: `RequireResourceIndicator`.
- **ApiScopes / IdentityResources**: possibly `RequireResourceIndicator` fields.
- **PersistedGrants**: `ConsumedTime`, `SessionId`, `Description`, and key changes.
- **New tables**: `Keys` (signing key management), `ServerSideSessions`, `PushedAuthorizationRequests`, and Identity providers table (`IdentityProviders`).
- `DeviceCodes` additions.

Apply operational store migration across rolling deployments carefully.
