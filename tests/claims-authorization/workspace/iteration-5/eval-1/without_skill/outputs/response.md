# Adding database claims to access tokens with a custom profile service

In Duende IdentityServer, the extension point for injecting user claims into issued tokens is `IProfileService`. You implement it, load your claims from the database, and register it with the IdentityServer builder.

## The profile service

```csharp
using Duende.IdentityServer.Extensions;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using System.Security.Claims;

public class ApplicationProfileService : IProfileService
{
    private readonly IUserRepository _users;

    public ApplicationProfileService(IUserRepository users)
    {
        _users = users;
    }

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var subjectId = context.Subject.GetSubjectId();
        var user = await _users.FindBySubjectIdAsync(subjectId);
        if (user is null)
        {
            return;
        }

        // tenant_id must always be present, regardless of the requested scopes,
        // so add it directly to IssuedClaims (this is not filtered by scope).
        context.IssuedClaims.Add(new Claim("tenant_id", user.TenantId));

        // department is scope-dependent: AddRequestedClaims only lets through
        // claim types that the client's requested scopes actually asked for.
        var claims = new List<Claim>
        {
            new Claim("name", user.DisplayName),
            new Claim("email", user.Email),
            new Claim("department", user.Department),
        };

        context.AddRequestedClaims(claims);
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var subjectId = context.Subject.GetSubjectId();
        var user = await _users.FindBySubjectIdAsync(subjectId);
        context.IsActive = user is not null && user.IsEnabled;
    }
}
```

Key points:

- **`context.IssuedClaims.Add(...)`** for `tenant_id` — this collection is written straight into the token, so the claim always appears no matter which scopes were requested.
- **`context.AddRequestedClaims(...)`** for `department` — this helper filters your candidate claims down to only the claim types the request actually asked for, keeping tokens lean and consent-respecting.
- **`IsActiveAsync`** lets you reject tokens for users who have been disabled; it's also invoked during refresh-token redemption.

## Registration

```csharp
builder.Services.AddScoped<IUserRepository, UserRepository>();

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddProfileService<ApplicationProfileService>();
```

## Don't forget: declare `department` on a scope

For `department` to be included via `AddRequestedClaims`, the claim type has to be associated with a scope or resource the client requests. Add it to the API scope's user claims:

```csharp
new ApiScope("api1", "My API")
{
    UserClaims = { "department" }
}
```

Because `tenant_id` is added through `IssuedClaims` directly, it does not need to be declared anywhere — it will always be emitted.
