# Migrating ApiResource Scopes from v3 to v4

In IdentityServer4 v3, scopes were nested inside ApiResource. In v4, they're separate top-level entities.

## Code Changes

### v3 (old)
```csharp
new ApiResource("api1", "My API")
{
    Scopes = { new Scope("api1") }
}
```

### v4 (new)
```csharp
// Scopes are now top-level
public static IEnumerable<ApiScope> ApiScopes => new[]
{
    new ApiScope("api1", "My API")
};

public static IEnumerable<ApiResource> ApiResources => new[]
{
    new ApiResource("api1", "My API")
    {
        Scopes = { "api1" }  // String references to scope names
    }
};

// Register separately
services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources);
```

## Database Migration

Run EF Core migrations after updating the code:

```bash
dotnet ef migrations add V4Update -c ConfigurationDbContext
dotnet ef database update -c ConfigurationDbContext
```

Be careful with the auto-generated migration — review it before applying to production.
