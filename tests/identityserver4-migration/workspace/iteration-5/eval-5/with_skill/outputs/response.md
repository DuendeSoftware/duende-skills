# IdentityServer4 v3 → v4: restructuring `ApiResource` scopes

In v3, `ApiScope` was a **child** of `ApiResource` (a parent-child relationship, with scopes expressed as nested `Scope` objects). In v4 this became a **many-to-many** relationship: scopes are independent, top-level `ApiScope` objects, and an `ApiResource` merely references them **by name (string)**. You register the scopes separately.

## Code restructuring

Your current `Config.cs` is actually already close to the v4 shape (it defines `ApiScopes` and references `"api1"` as a string), but here is the full v3 → v4 transformation so the pattern is clear.

```csharp
// v3 — scopes nested inside the ApiResource as Scope objects
public static IEnumerable<ApiResource> ApiResources =>
    new[]
    {
        new ApiResource("api1", "My API")
        {
            Scopes = { new Scope("api1.read"), new Scope("api1.write") }
        }
    };
```

```csharp
// v4 — ApiScope is an independent top-level object...
public static IEnumerable<ApiScope> ApiScopes =>
    new[]
    {
        new ApiScope("api1.read", "Read access to API 1"),
        new ApiScope("api1.write", "Write access to API 1")
    };

// ...and ApiResource references scopes by string name, not Scope objects
public static IEnumerable<ApiResource> ApiResources =>
    new[]
    {
        new ApiResource("api1", "My API")
        {
            Scopes = { "api1.read", "api1.write" }   // string references
        }
    };
```

Register the scopes **separately** with `AddInMemoryApiScopes` (new in v4), alongside the resources:

```csharp
services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)       // NEW in v4 — required
    .AddInMemoryApiResources(Config.ApiResources)
    .AddInMemoryClients(Config.Clients);
```

If you see a compile error that `Scope` cannot be found — that's expected. The nested `Scope` type was removed in v4; use top-level `ApiScope` objects and string references.

## Database migration — handle with care

The v3 → v4 `ConfigurationDbContext` schema change **renames tables and restructures relationships**. Table renames include:

- `ApiClaims` → `ApiResourceClaims`
- `ApiProperties` → `ApiResourceProperties`
- `ApiSecrets` → `ApiResourceSecrets`
- `IdentityClaims` → `IdentityResourceClaims`
- `IdentityProperties` → `IdentityResourceProperties`

and the scope relationship is moved to an `ApiResourceScopes` join table (scopes become independent).

**Do not rely on an auto-generated EF Core migration for this step.** EF sees the renamed tables as "drop old + create new" and will **drop and recreate the tables, losing all data**. Instead:

1. Scaffold the migration:
   ```bash
   dotnet ef migrations add Config_v4 -c ConfigurationDbContext -o Migrations/ConfigurationDb
   ```
2. Edit the generated migration to run a **custom delta SQL script** that copies data from the old tables into the new ones *before* the destructive drops, e.g.:
   ```sql
   INSERT INTO ApiResourceClaims (Id, [Type], ApiResourceId)
   SELECT Id, [Type], ApiResourceId FROM ApiClaims;

   INSERT INTO ApiResourceProperties (Id, [Key], [Value], ApiResourceId)
   SELECT Id, [Key], [Value], ApiResourceId FROM ApiProperties;

   -- move scope→resource links into the new join table
   INSERT INTO ApiResourceScopes ([Scope], [ApiResourceId])
   SELECT [Name], [ApiResourceId] FROM ApiScopes;
   ```
3. Apply: `dotnet ef database update -c ConfigurationDbContext`

The `PersistedGrantDbContext` change for v4 is additive (`ConsumedTime`, `Description`, `SessionId`) and can use a standard migration.

Duende publishes a reference project for exactly this v3 upgrade: **UpgradeSample-IdentityServer4-v3**.
