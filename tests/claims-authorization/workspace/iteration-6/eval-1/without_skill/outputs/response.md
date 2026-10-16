# Custom IProfileService for `department` and `tenant_id`

## 1. Implement the service

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Extensions;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class AppProfileService(IUserStore users, ILogger<AppProfileService> logger) : IProfileService
{
    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var sub = context.Subject.GetSubjectId();
        var user = await users.FindBySubjectIdAsync(sub);
        if (user is null) return;

        // Filtered claims: only issued if the requested resources declare them
        var claims = new List<Claim>
        {
            new("department", user.Department),
        };
        context.AddRequestedClaims(claims);

        // Always present: bypasses claims filtering by adding straight to IssuedClaims
        context.IssuedClaims.Add(new Claim("tenant_id", user.TenantId));
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var user = await users.FindBySubjectIdAsync(context.Subject.GetSubjectId());
        context.IsActive = user is { IsEnabled: true };
    }
}
```

`AddRequestedClaims` only keeps claim types listed in `context.RequestedClaimTypes` (taken from `UserClaims` on the requested scopes/resources). `IssuedClaims.Add` is not filtered, so `tenant_id` is always emitted.

## 2. Register it

```csharp
builder.Services.AddScoped<IUserStore, EfUserStore>();

builder.Services.AddIdentityServer(options => { options.EmitStaticAudienceClaim = true; })
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddProfileService<AppProfileService>();
```
Drop `.AddTestUsers(...)` (it registers its own `TestUserProfileService`; the last registration wins, but remove it to avoid confusion).

## 3. Declare `department` on the scope

```csharp
new ApiScope("api1", "My API") { UserClaims = { "department" } }
```
Without this, `AddRequestedClaims` filters `department` out of the access token. `tenant_id` needn't be declared because it's added directly.

## Notes
- `IsActiveAsync` is called on refresh/introspection/userinfo, so keep it cheap.
- For client-credentials tokens there is no user, so `tenant_id` from the profile service isn't used; use `Client.Claims` there.
- Always-present `tenant_id` also applies to identity tokens/userinfo calls if you add it unconditionally; guard with `context.Caller` if undesired.
