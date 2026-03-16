# Custom IProfileService for Duende IdentityServer

Here's how to build a custom `IProfileService` that loads `department` and `tenant_id` claims from your database, with `tenant_id` always present in every token regardless of scopes.

## Implementation

The recommended approach is to extend `DefaultProfileService` so you inherit baseline behavior and only override what you need.

```csharp
using System.Security.Claims;
using Duende.IdentityModel;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

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

        // Mandatory claim — always emitted regardless of requested scopes.
        // Use context.IssuedClaims.Add to bypass scope-based filtering.
        context.IssuedClaims.Add(new Claim("tenant_id", user.TenantId));

        // Scope-filtered claims — only emitted when the client requests 
        // the scope that declares these claim types in its UserClaims collection.
        var scopeFilteredClaims = new List<Claim>
        {
            new(JwtClaimTypes.Name, user.DisplayName),
            new(JwtClaimTypes.Email, user.Email),
            new("department", user.Department),
        };

        // AddRequestedClaims filters claims to only those in context.RequestedClaimTypes
        context.AddRequestedClaims(scopeFilteredClaims);
    }

    public override async Task IsActiveAsync(IsActiveContext context)
    {
        var subjectId = context.Subject.GetSubjectId();
        var user = await _users.FindBySubjectIdAsync(subjectId);

        // If user is null or disabled, mark as inactive.
        // This prevents token issuance for deactivated accounts
        // and is also checked during refresh token redemption.
        context.IsActive = user is { IsEnabled: true };
    }
}
```

## Registration

Register your profile service with `AddProfileService<T>()` on the IdentityServer builder in `Program.cs`:

```csharp
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

## Important: Declare Claims on Scopes

For `department` to appear in access tokens via `AddRequestedClaims`, it must be declared in the `UserClaims` collection of the relevant `ApiScope`:

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API")
    {
        UserClaims = { "department" }
    }
];
```

The `tenant_id` claim doesn't need to be declared on a scope because we're using `context.IssuedClaims.Add()` directly, which bypasses scope filtering entirely. This ensures every access token contains `tenant_id` regardless of which scopes the client requests.

## Key Points

- **`context.AddRequestedClaims(claims)`** filters your claims to only those in `context.RequestedClaimTypes` (driven by the scopes the client requested). Use this for opt-in claims like `department`.
- **`context.IssuedClaims.Add(...)`** bypasses all scope filtering — the claim always appears. Use this for mandatory claims like `tenant_id`.
- **`IsActiveAsync`** is called on every token issuance including refresh token redemptions. Return `false` to block tokens for disabled users.
