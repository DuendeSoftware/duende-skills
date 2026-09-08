# Custom `IProfileService` with a mandatory `tenant_id` claim

In Duende IdentityServer, `IProfileService` is the single authoritative extension point for controlling which user claims enter identity tokens, access tokens, and the userinfo endpoint. The key nuance in your requirement is:

- `department` is a **scope-filtered** claim — it should only appear when a requested scope declares it. Use `context.AddRequestedClaims(...)` so IdentityServer filters it against `RequestedClaimTypes`.
- `tenant_id` is **mandatory** — it must be present in *every* token regardless of scopes. For that, add it directly to `context.IssuedClaims`, which bypasses the scope/consent filter.

## 1. The profile service

Extend `DefaultProfileService` so you inherit the built-in logging/behavior, and only override what you need.

```csharp
using Duende.IdentityServer.Extensions;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Duende.IdentityModel; // JwtClaimTypes
using System.Security.Claims;

public sealed class ApplicationProfileService : DefaultProfileService
{
    private readonly IUserRepository _users;
    private readonly ILogger<ApplicationProfileService> _logger;

    public ApplicationProfileService(
        IUserRepository users,
        ILogger<ApplicationProfileService> logger)
        : base(logger)
    {
        _users = users;
        _logger = logger;
    }

    public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var subjectId = context.Subject.GetSubjectId();

        var user = await _users.FindBySubjectIdAsync(subjectId);
        if (user is null)
        {
            _logger.LogWarning("Profile service: user {SubjectId} not found", subjectId);
            return;
        }

        // Mandatory claim — added directly to IssuedClaims so it bypasses
        // scope-based filtering and appears in EVERY token.
        context.IssuedClaims.Add(new Claim("tenant_id", user.TenantId));

        // Scope-filtered claims — only emitted if the requested scopes declare them.
        var requestedClaims = new List<Claim>
        {
            new(JwtClaimTypes.Name, user.DisplayName),
            new(JwtClaimTypes.Email, user.Email),
            new("department", user.Department),
        };

        context.AddRequestedClaims(requestedClaims);
    }

    public override async Task IsActiveAsync(IsActiveContext context)
    {
        var subjectId = context.Subject.GetSubjectId();
        var user = await _users.FindBySubjectIdAsync(subjectId);

        // Called at the authorize/token endpoints and on refresh token redemption.
        context.IsActive = user is { IsEnabled: true };
    }
}
```

Why `IssuedClaims.Add` for `tenant_id` and `AddRequestedClaims` for the rest:

- `context.AddRequestedClaims(claims)` only lets through claims whose type appears in `context.RequestedClaimTypes` (built from the `UserClaims` of the requested `IdentityResource`/`ApiScope`/`ApiResource`). So `department` will only show up when a requested scope declares `department`.
- `context.IssuedClaims.Add(...)` is unconditional — perfect for a mandatory multi-tenancy claim that APIs always rely on.

## 2. Register it

```csharp
// Program.cs
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddProfileService<ApplicationProfileService>();   // ← register the profile service

// Your data access
builder.Services.AddScoped<IUserRepository, UserRepository>();
```

## 3. Make `department` reachable (don't forget the scope wiring)

Emitting `department` from the profile service is **not enough** — claims are opt-in by scope. The claim type must be declared in a resource's `UserClaims` collection, and the client must request that scope. For example, declare it on the `api1` scope (or a dedicated identity resource):

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API")
    {
        UserClaims = { "department" }   // now "department" is in RequestedClaimTypes
    }
];
```

and ensure the client's `AllowedScopes` include that scope (your `interactive` and `m2m.client` already allow `api1`).

`tenant_id` needs **no** such declaration because it goes straight into `IssuedClaims`.

## Summary

| Claim | How it's added | Appears when |
|---|---|---|
| `tenant_id` | `context.IssuedClaims.Add(...)` | Always, in every token |
| `department` | `context.AddRequestedClaims(...)` | Only when a requested scope declares it in `UserClaims` |

This gives you a repository-backed profile service, scope-respecting `department`, an always-present `tenant_id`, a working `IsActiveAsync`, and a single `AddProfileService<ApplicationProfileService>()` registration.
