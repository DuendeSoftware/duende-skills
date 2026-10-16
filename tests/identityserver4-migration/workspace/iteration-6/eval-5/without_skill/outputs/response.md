## v3 → v4 scope restructuring

In v3, an `ApiResource` contained `Scopes = { new Scope("api1") }`. In v4 scopes are top-level `ApiScope` objects, and `ApiResource.Scopes` is just a list of scope names.

**Before (v3)**
```csharp
new ApiResource("api1", "My API")
{
    Scopes = { new Scope("api1.read"), new Scope("api1.write") }
}
```
**After (v4)**
```csharp
public static IEnumerable<ApiScope> ApiScopes => new[]
{
    new ApiScope("api1.read", "Read"),
    new ApiScope("api1.write", "Write")
};

public static IEnumerable<ApiResource> ApiResources => new[]
{
    new ApiResource("api1", "My API") { Scopes = { "api1.read", "api1.write" } }
};
```
Register: `.AddInMemoryApiScopes(Config.ApiScopes).AddInMemoryApiResources(Config.ApiResources)`. Your Config.cs already uses this v4 shape.

**Database**: the v4 EF schema adds an `ApiScopes` table (with claims and properties) and the `ApiResourceScopes` table; the old `ApiScopes` (which was linked to ApiResource) is renamed/restructured. Steps: install v4 packages, `dotnet ef migrations add Config_v4 -c ConfigurationDbContext`, then edit the migration to avoid data loss — the IS4 repository provides a SQL migration script to move data from old tables into new ones (rename old tables, create new, copy `ApiScopes` rows to `ApiResourceScopes` and new `ApiScopes`). Back up first, then update. Also note clients need `AllowedScopes` to refer to scope names, and `scope` claim handling in access tokens.
