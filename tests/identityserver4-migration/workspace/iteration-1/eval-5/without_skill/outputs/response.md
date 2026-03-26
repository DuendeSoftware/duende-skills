# Migrating ApiResource Scopes from v3 to v4

## The Change

In IdentityServer4 v3, scopes were nested inside `ApiResource`. In v4, `ApiScope` became a standalone top-level entity.

### v3 Style
```csharp
new ApiResource("api1")
{
    Scopes = { new Scope("api1.read"), new Scope("api1.write") }
}
```

### v4 Style
```csharp
// Scopes are now independent
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
        Scopes = { "api1.read", "api1.write" }  // strings, not objects
    }
};
```

### Registration
```csharp
services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources)
    .AddInMemoryClients(Config.Clients);
```

## Database Migration

If you're using EF Core stores, you'll need to create a migration:

```bash
dotnet ef migrations add V3toV4 -c ConfigurationDbContext
```

**Be careful** — the schema change is significant and a simple auto-generated migration might not handle the data correctly. You may want to review the migration carefully and consider writing custom SQL to preserve data.

The migration involves restructuring how scopes relate to API resources in the database schema.
