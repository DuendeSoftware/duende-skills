# Custom `IProfileService` with `department` and an always-present `tenant_id`

Claims are opt-in by scope: IdentityServer asks the profile service for claims declared in `UserClaims` of the requested resources. `AddRequestedClaims` filters to those; `IssuedClaims.Add` bypasses the filter. That's how `tenant_id` can be unconditional.

## 1. Profile service

```csharp
using System.Security.Claims;
using Duende.IdentityModel;
using Duende.IdentityServer.Extensions;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public sealed class ApplicationProfileService(
    IUserRepository users,
    ILogger<ApplicationProfileService> logger) : DefaultProfileService(logger)
{
    public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var subjectId = context.Subject.GetSubjectId();
        var user = await users.FindBySubjectIdAsync(subjectId);
        if (user is null)
        {
            logger.LogWarning("Profile service: user {SubjectId} not found", subjectId);
            return;
        }

        // Mandatory claim: bypasses scope-based filtering, so it's in every token
        context.IssuedClaims.Add(new Claim("tenant_id", user.TenantId));

        // Scope-filtered claims: only emitted if declared in UserClaims of a requested resource
        context.AddRequestedClaims(new[]
        {
            new Claim("department", user.Department),
            new Claim(JwtClaimTypes.Name, user.DisplayName),
        });
    }

    public override async Task IsActiveAsync(IsActiveContext context)
    {
        var user = await users.FindBySubjectIdAsync(context.Subject.GetSubjectId());
        context.IsActive = user is { IsEnabled: true };
    }
}
```

## 2. Register it

```csharp
builder.Services.AddScoped<IUserRepository, EfUserRepository>();

builder.Services.AddIdentityServer(options => { options.EmitStaticAudienceClaim = true; })
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddProfileService<ApplicationProfileService>();   // replaces .AddTestUsers(...)
```

## 3. Declare `department` on the scope (required!)

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API") { UserClaims = { "department" } }
];
```

Without `UserClaims = { "department" }`, `AddRequestedClaims` silently drops it even though the service emits it. `tenant_id` doesn't need declaring since it goes straight to `IssuedClaims`. The client must also request the `api1` scope (it's already in `AllowedScopes` for `interactive`).

## Notes
- **Don't overuse `IssuedClaims`** for everything: it ignores scopes and consent. Reserve it for must-have claims like `tenant_id`.
- **Client credentials**: there's no user, so the profile service isn't called for `m2m.client`. Use `Client.Claims` there (`new ClientClaim("tenant_id", "...")`).
- **Refresh**: `IsActiveAsync` always runs on refresh; `GetProfileDataAsync` re-runs only if `UpdateAccessTokenClaimsOnRefresh = true`.
- Cache expensive lookups (`IMemoryCache`, TTL shorter than token lifetime), as this runs on every issuance.
- Debug: enable `Duende.IdentityServer` debug logging to see requested vs. issued claim types.
