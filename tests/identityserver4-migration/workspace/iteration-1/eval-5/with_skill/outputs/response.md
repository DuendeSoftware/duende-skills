# Migrating ApiResource Scopes: IdentityServer4 v3 → v4

## The Breaking Change

In IdentityServer4 v3, `ApiScope` was a **child object** of `ApiResource` — scopes were nested directly within the resource. In v4, scopes became **independent top-level objects** with a many-to-many relationship to API resources. This was a fundamental restructuring of how scopes and resources relate.

## Code Changes

### Before (v3): Scopes nested inside ApiResource

```csharp
public static IEnumerable<ApiResource> ApiResources => new[]
{
    new ApiResource("api1", "My API")
    {
        Scopes = { new Scope("api1.read"), new Scope("api1.write") }
    }
};
```

### After (v4): ApiScope is top-level, ApiResource references by name

```csharp
// Step 1: Define scopes as independent top-level objects
public static IEnumerable<ApiScope> ApiScopes => new[]
{
    new ApiScope("api1.read", "Read access to API 1"),
    new ApiScope("api1.write", "Write access to API 1")
};

// Step 2: ApiResource.Scopes now contains string names, not Scope objects
public static IEnumerable<ApiResource> ApiResources => new[]
{
    new ApiResource("api1", "My API")
    {
        Scopes = { "api1.read", "api1.write" }  // string references
    }
};
```

### Step 3: Register API Scopes separately in DI

```csharp
services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)       // NEW — required in v4
    .AddInMemoryApiResources(Config.ApiResources)
    .AddInMemoryClients(Config.Clients);
```

## Database Migration (v3 → v4 ConfigurationDbContext)

**Warning: Do NOT rely on auto-generated EF Core migrations for this schema change.** A naive `dotnet ef migrations add` will generate a migration that drops the old tables and recreates them, **destroying all existing data**.

### What Changed in the Schema

The v3 → v4 migration renames several tables:

| Old Table (v3) | New Table (v4) |
|----------------|----------------|
| `ApiClaims` | `ApiResourceClaims` |
| `ApiProperties` | `ApiResourceProperties` |
| `ApiSecrets` | `ApiResourceSecrets` |
| `IdentityClaims` | `IdentityResourceClaims` |
| `IdentityProperties` | `IdentityResourceProperties` |

The `ApiScopes` table is restructured: the foreign key to `ApiResources` is removed, and a new `ApiResourceScopes` join table is created for the many-to-many relationship.

### Safe Migration Approach

1. **Create the migration scaffold** (but don't apply it yet):
   ```bash
   dotnet ef migrations add Config_v4 -c ConfigurationDbContext -o Migrations/ConfigurationDb
   ```

2. **Embed a custom delta SQL script** in the migration that moves data before dropping old tables:
   ```sql
   -- Rename tables (preserve data)
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

3. **Modify the generated migration** to execute the SQL script before the destructive operations.

4. **Apply the migration**:
   ```bash
   dotnet ef database update -c ConfigurationDbContext
   ```

### Reference

See the [UpgradeSample-IdentityServer4-v3](https://github.com/DuendeSoftware/UpgradeSample-IdentityServer4-v3) repository for a complete working example of this migration.
