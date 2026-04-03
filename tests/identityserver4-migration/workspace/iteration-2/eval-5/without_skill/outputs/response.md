# Migrating ApiResource Scopes from v3 to v4

In IdentityServer4 v3, scopes were nested inside `ApiResource`. In v4, they became separate objects.

## Code Changes

### v3 (nested scopes)
```csharp
new ApiResource("api1")
{
    Scopes = { new Scope("api1.read"), new Scope("api1.write") }
}
```

### v4 (independent scopes)
```csharp
// Scopes are now top-level
public static IEnumerable<ApiScope> ApiScopes => new[]
{
    new ApiScope("api1.read"),
    new ApiScope("api1.write")
};

// ApiResource references scopes by name
public static IEnumerable<ApiResource> ApiResources => new[]
{
    new ApiResource("api1")
    {
        Scopes = { "api1.read", "api1.write" }
    }
};
```

You'll need to register both separately:
```csharp
services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources);
```

## Database Migration

For the database, you'll need to create a new EF Core migration:

```bash
dotnet ef migrations add UpdateApiScopes -c ConfigurationDbContext
```

Review the generated migration carefully. The schema change is significant since scopes are now in their own table. You may need to manually adjust the migration to preserve existing data.

Apply with:
```bash
dotnet ef database update -c ConfigurationDbContext
```
