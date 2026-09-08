# Migrating scopes from IdentityServer4 v3 to v4

The big model change in v4 was decoupling scopes from API resources. In v3 an `ApiResource` owned its scopes as nested `Scope` objects. In v4, `ApiScope` is a standalone, top-level concept, and an `ApiResource` just lists the scope **names** it exposes. This lets a single scope belong to multiple resources.

## Restructuring the code

```csharp
// v3: scopes nested inside the resource
new ApiResource("api1", "My API")
{
    Scopes =
    {
        new Scope("api1.read"),
        new Scope("api1.write")
    }
};
```

becomes

```csharp
// v4: scopes are independent top-level objects
public static IEnumerable<ApiScope> ApiScopes =>
    new[]
    {
        new ApiScope("api1.read", "Read access"),
        new ApiScope("api1.write", "Write access")
    };

// the resource references scope names as strings
public static IEnumerable<ApiResource> ApiResources =>
    new[]
    {
        new ApiResource("api1", "My API")
        {
            Scopes = { "api1.read", "api1.write" }
        }
    };
```

Then register the scopes on their own, in addition to the resources:

```csharp
services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources)
    .AddInMemoryClients(Config.Clients);
```

The `AddInMemoryApiScopes` call is the new piece — without it your API scopes won't be known to the server. Note the `Scope` class no longer exists in v4, so any remaining references to it will fail to compile; replace them with `ApiScope` and string references.

Your current `Config.cs` is already written in the v4 style (it has a separate `ApiScopes` collection and references `"api1"` as a string), so if you're starting from that file the in-memory side is essentially done.

## About the database

If you use the EF Core configuration store, the underlying schema for API resources and scopes changed as part of this decoupling, so you'll need a database migration to match. Scaffold it with `dotnet ef migrations add` against the `ConfigurationDbContext` and review it carefully before applying — schema changes of this kind can be destructive, so back up the database first and verify the migration preserves your existing clients, resources, and scopes rather than dropping and recreating tables. Test against a copy of production data before running it for real.
