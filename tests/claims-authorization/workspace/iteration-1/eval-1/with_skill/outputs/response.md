# Custom IProfileService for Duende IdentityServer

To include custom claims like `department` and `tenant_id` in access tokens, you need a custom `IProfileService` implementation. The key distinction is between scope-filtered claims (use `AddRequestedClaims`) and mandatory claims (use `IssuedClaims.Add`).

## Custom Profile Service

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Extensions;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using IdentityModel;

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
            _logger.LogWarning("User {SubjectId} not found", subjectId);
            return;
        }

        // Mandatory claim — always present regardless of requested scopes
        // Use IssuedClaims.Add to bypass scope filtering
        context.IssuedClaims.Add(new Claim("tenant_id", user.TenantId));

        // Scope-filtered claims — only emitted when the corresponding scope is requested
        // AddRequestedClaims filters to only those in context.RequestedClaimTypes
        var profileClaims = new List<Claim>
        {
            new(JwtClaimTypes.Name, user.DisplayName),
            new(JwtClaimTypes.Email, user.Email),
            new("department", user.Department),
        };
        context.AddRequestedClaims(profileClaims);
    }

    public override async Task IsActiveAsync(IsActiveContext context)
    {
        var subjectId = context.Subject.GetSubjectId();
        var user = await _users.FindBySubjectIdAsync(subjectId);
        context.IsActive = user is { IsEnabled: true };
    }
}
```

## Registration in Program.cs

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddProfileService<ApplicationProfileService>();  // Register custom profile service
```

## How It Works

- **`DefaultProfileService`**: Extending this base class gives you a sensible default that already handles standard claims. You override only what you need.
- **`context.IssuedClaims.Add(...)`**: Adds `tenant_id` unconditionally — it bypasses `RequestedClaimTypes` filtering, so it always appears in every token regardless of scopes.
- **`context.AddRequestedClaims(...)`**: Filters the provided claims to only emit those whose types are in `context.RequestedClaimTypes` (derived from the client's requested scopes and the `UserClaims` declared on those scopes).
- **`IsActiveAsync`**: Called on every token issuance including refresh token redemption. Returns whether the user account is still active.
- **`AddProfileService<T>()`**: Registers your implementation with IdentityServer's DI. Only one profile service can be active.

> **Important**: For `department` to appear in tokens via `AddRequestedClaims`, it must be declared in the `UserClaims` collection of an `ApiScope` or `ApiResource`, and the client must request that scope.
