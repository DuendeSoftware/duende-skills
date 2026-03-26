# Setting Up IdentityServer with In-Memory Stores

Here's how to set up a basic IdentityServer host:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("weatherapi", "Weather API")
    })
    .AddDeveloperSigningCredential();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.Run();
```

This sets up IdentityServer with:
- OpenID and Profile identity resources
- A `weatherapi` API scope
- Developer signing credential (for development only)

The identity resources define what user claims are available, while the API scope defines what APIs clients can access.
