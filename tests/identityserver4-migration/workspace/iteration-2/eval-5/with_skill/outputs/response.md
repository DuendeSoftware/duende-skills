# Migrating ApiResource/ApiScope from IdentityServer4 v3 to v4

In IdentityServer4 v3, `ApiScope` was a child object nested inside `ApiResource`. In v4, scopes became independent top-level objects with a many-to-many relationship to API resources.

## Code Changes

### Before (v3): Scopes nested inside ApiResource

```csharp
// v3: Scopes are child objects of ApiResource
new ApiResource("api1", "My API")
{
    Scopes = { new Scope("api1.read"), new Scope("api1.write") }
}
```

### After (v4): ApiScope is a top-level independent object

```csharp
// v4: ApiScope is a top-level independent object
public static IEnumerable<ApiScope> ApiScopes => new[]
{
    new ApiScope("api1.read", "Read access to API 1"),
    new ApiScope("api1.write", "Write access to API 1")
};

// v4: ApiResource.Scopes contains string scope names (not Scope objects)
public static IEnumerable<ApiResource> ApiResources => new[]
{
    new ApiResource("api1", "My API")
    {
        Scopes = { "api1.read", "api1.write" } // string references
    }
};
```

### Register API scopes separately

```csharp
services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)       // NEW in v4 — register scopes separately
    .AddInMemoryApiResources(Config.ApiResources)
    .AddInMemoryClients(Config.Clients);
```

## Database Migration (v3 → v4 ConfigurationDbContext)

**Warning: Do not rely on auto-generated EF Core migrations for this step — they will drop and recreate tables, losing data.**

The v3 → v4 schema renames tables:
- `ApiClaims` → `ApiResourceClaims`
- `ApiProperties` → `ApiResourceProperties`
- `ApiSecrets` → `ApiResourceSecrets`
- `IdentityClaims` → `IdentityResourceClaims`
- `IdentityProperties` → `IdentityResourceProperties`

And restructures the `ApiScopes` relationship (scopes become independent, linked via `ApiResourceScopes` join table).

### Recommended approach:

1. **Create the migration scaffold:**
   ```bash
   dotnet ef migrations add Config_v4 -c ConfigurationDbContext -o Migrations/ConfigurationDb
   ```

2. **Embed a custom delta SQL script** that moves data before dropping old tables:
   ```sql
   INSERT INTO ApiResourceClaims (Id, [Type], ApiResourceId)
   SELECT Id, [Type], ApiResourceId FROM ApiClaims;

   INSERT INTO ApiResourceProperties (Id, [Key], [Value], ApiResourceId)
   SELECT Id, [Key], [Value], ApiResourceId FROM ApiProperties;

   INSERT INTO ApiResourceSecrets (Id, [Description], [Value], [Expiration], [Type], [Created], ApiResourceId)
   SELECT Id, [Description], [Value], [Expiration], [Type], [Created], ApiResourceId FROM ApiSecrets;

   INSERT INTO IdentityResourceClaims (Id, [Type], IdentityResourceId)
   SELECT Id, [Type], IdentityResourceId FROM IdentityClaims;

   INSERT INTO IdentityResourceProperties (Id, [Key], [Value], IdentityResourceId)
   SELECT Id, [Key], [Value], IdentityResourceId FROM IdentityProperties;

   -- Migrate scope-resource relationship to join table
   INSERT INTO ApiResourceScopes ([Scope], [ApiResourceId])
   SELECT [Name], [ApiResourceId] FROM ApiScopes;
   ```

3. **Modify** the generated migration to execute the SQL script before the destructive operations.

4. **Apply:** `dotnet ef database update -c ConfigurationDbContext`

See the [UpgradeSample-IdentityServer4-v3](https://github.com/DuendeSoftware/UpgradeSample-IdentityServer4-v3) reference project for a complete working example.
