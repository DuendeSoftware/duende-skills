# Getting an `aud` Claim for a Single API

The most straightforward way to get an `aud` (audience) claim into your access tokens is to define a minimal **API Resource**. The audience claim in IdentityServer is derived from the API Resource name, so even a single, small resource definition gives you the `aud` you need.

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<ApiScope> ApiScopes =>
        new ApiScope[]
        {
            new ApiScope("my_api", "My API")
        };

    public static IEnumerable<ApiResource> ApiResources =>
        new ApiResource[]
        {
            new ApiResource("my-api", "My API")
            {
                Scopes = { "my_api" }
            }
        };
}
```

Register it:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryApiResources(Config.ApiResources);
```

Now tokens requested for `my_api` carry:

```json
{
  "aud": "my-api",
  "scope": "my_api"
}
```

And your API validates that audience:

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer(o =>
    {
        o.Authority = "https://your-identityserver";
        o.Audience  = "my-api";
    });
```

## Notes

- Defining a single `ApiResource` is minimal and gives you a clean, API-specific `aud` value (`my-api`).
- With only API Scopes and no API Resource, no `aud` claim is added — that's why the resource is needed.
- This approach scales cleanly if you add more APIs later, and avoids any deprecated flows.
