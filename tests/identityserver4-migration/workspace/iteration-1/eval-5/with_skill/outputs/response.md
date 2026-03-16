# Migrating ApiResource Scopes from v3 to v4

## The Breaking Change

In IdentityServer4 v3, `ApiScope` was a child of `ApiResource` (nested `Scope` objects). In v4, scopes are independent top-level objects with a many-to-many relationship.

## Code Changes

### Before (v3 style)

```csharp
new ApiResource("api1", "My API")
{
    Scopes = { new Scope("api1.read"), new Scope("api1.write") }
}
```

### After (v4 style) — ApiScope as Top-Level Object

```csharp
// ApiScopes are now independent top-level objects
public static IEnumerable<ApiScope> ApiScopes => new[]
{
    new ApiScope("api1", "My API"),
    new ApiScope("api1.read", "Read access to API 1"),
    new ApiScope("api1.write", "Write access to API 1")
};

// ApiResource.Scopes contains string scope names, not Scope objects
public static IEnumerable<ApiResource> ApiResources => new[]
{
    new ApiResource("api1", "My API")
    {
        Scopes = { "api1", "api1.read", "api1.write" }  // string references
    }
};
```

### Register Both Separately

```csharp
services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)       // Register API scopes separately
    .AddInMemoryApiResources(Config.ApiResources)
    .AddInMemoryClients(Config.Clients);
```

## Database Migration Warning

**Do not rely on auto-generated EF Core migrations for the v3 → v4 `ConfigurationDbContext` schema change — they will drop and recreate tables, losing data.**

The v3 → v4 schema change renames tables:
- `ApiClaims` → `ApiResourceClaims`
- `ApiProperties` → `ApiResourceProperties`
- `ApiSecrets` → `ApiResourceSecrets`
- `IdentityClaims` → `IdentityResourceClaims`
- `IdentityProperties` → `IdentityResourceProperties`

And restructures the `ApiScopes` relationship (scopes become independent, linked via `ApiResourceScopes` join table).

### Recommended Approach

1. Create the migration scaffold:
   ```bash
   dotnet ef migrations add Config_v4 -c ConfigurationDbContext
   ```

2. Embed a custom delta SQL script that migrates data before dropping old tables:
   ```sql
   INSERT INTO ApiResourceClaims (Id, [Type], ApiResourceId)
   SELECT Id, [Type], ApiResourceId FROM ApiClaims;

   INSERT INTO ApiResourceProperties (Id, [Key], [Value], ApiResourceId)
   SELECT Id, [Key], [Value], ApiResourceId FROM ApiProperties;

   INSERT INTO ApiResourceSecrets (Id, [Description], [Value], [Expiration], [Type], [Created], ApiResourceId)
   SELECT Id, [Description], [Value], [Expiration], [Type], [Created], ApiResourceId FROM ApiSecrets;
   ```

3. Modify the generated migration to execute the SQL before destructive operations.
4. Apply: `dotnet ef database update -c ConfigurationDbContext`
