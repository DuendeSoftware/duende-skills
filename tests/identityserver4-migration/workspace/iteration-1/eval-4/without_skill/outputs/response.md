# Database Migrations for Duende IdentityServer

## Creating Migrations

After updating your packages, you need to create new EF Core migrations:

```bash
dotnet ef migrations add DuendeUpgrade -c PersistedGrantDbContext
dotnet ef migrations add DuendeUpgrade -c ConfigurationDbContext
```

Then apply them:

```bash
dotnet ef database update -c PersistedGrantDbContext
dotnet ef database update -c ConfigurationDbContext
```

## New Tables

Duende IdentityServer adds several new tables compared to IdentityServer4:

### Keys Table
The **`Keys`** table is used for **automatic key management**. Duende IdentityServer can automatically create, rotate, and retire signing keys, and this table stores them.

### ServerSideSessions Table
The **`ServerSideSessions`** table supports server-side session management, allowing you to query and manage active user sessions.

## New Columns

Duende adds new columns to existing tables:
- New client properties for features like **DPoP** (`RequireDPoP`) and **Pushed Authorization Requests** (`RequirePushedAuthorization`)
- Various timestamp columns for tracking

## Important

Review the generated migration carefully before applying it to production. Back up your database first.
