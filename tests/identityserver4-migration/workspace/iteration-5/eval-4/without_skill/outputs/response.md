# Database migrations after moving to Duende IdentityServer

Because Duende IdentityServer added several new features that persist state, both of your EF Core stores gain new tables and columns. You need to scaffold and apply a migration for each `DbContext`.

## Creating the migrations

```bash
dotnet ef migrations add UpdateToDuende -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef migrations add UpdateToDuende -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
```

## Applying them

```bash
dotnet ef database update -c ConfigurationDbContext
dotnet ef database update -c PersistedGrantDbContext
```

Your `Program.cs` already calls `Database.Migrate()` on both contexts at startup, so once the migration files exist they'll be applied automatically when the app runs.

## New tables and columns compared to IdentityServer4 v4

**Operational database (PersistedGrantDbContext):**

- **`Keys`** — Duende includes automatic (managed) signing-key rotation, and the keys are stored in this table. This is directly tied to removing `AddDeveloperSigningCredential()`.
- **`ServerSideSessions`** — supports Duende's server-side session feature (server-stored sessions instead of purely cookie-based).
- **`PushedAuthorizationRequests`** — backing store for Pushed Authorization Requests (PAR).

**Configuration database (ConfigurationDbContext):**

- **`IdentityProviders`** — stores dynamically-configured OIDC identity providers so you can add external providers without redeploying.
- New columns on `Clients` for the newer protocol features, including **`RequireDPoP`** (DPoP sender-constrained tokens) and **`RequirePushedAuthorization`** (force PAR for the client), plus `InitiateLoginUri`.
- Assorted new columns on existing entities for resource indicators and auditing timestamps.

## A word of caution

Always open the generated migration and read it before running `database update`. The v4 → Duende change is largely additive, but you want to confirm the migration only adds tables/columns and doesn't drop or recreate anything with data in it. Back up the database first.
