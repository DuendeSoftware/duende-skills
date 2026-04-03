# Custom IProfileService for Duende IdentityServer

Here's how to build and register a custom `IProfileService` that loads user claims like `department` and `tenant_id` from your database, with `tenant_id` always present regardless of scopes.

## Implementation

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Duende.IdentityModel;
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
            _logger.LogWarning("User {SubjectId} not found", subjectId);
            return;
        }

        // Mandatory claim — always present regardless of requested scopes
        // Use context.IssuedClaims.Add to bypass scope filtering
        context.IssuedClaims.Add(new Claim("tenant_id", user.TenantId));

        // Scope-filtered claims — only emitted when the client requests scopes
        // that declare these claim types in their UserClaims collection
        var claims = new List<Claim>
        {
            new(JwtClaimTypes.Name, user.DisplayName),
            new(JwtClaimTypes.Email, user.Email),
            new("department", user.Department),
        };

        // AddRequestedClaims filters to only claims in context.RequestedClaimTypes
        context.AddRequestedClaims(claims);
    }

    public override async Task IsActiveAsync(IsActiveContext context)
    {
        var subjectId = context.Subject.GetSubjectId();
        var user = await _users.FindBySubjectIdAsync(subjectId);
        context.IsActive = user is { IsEnabled: true };
    }
}
```

## Registration

Register the profile service in `Program.cs`:

```csharp
builder.Services.AddIdentityServer()
    .AddProfileService<ApplicationProfileService>();
```

## Declaring Claims on Scopes

For scope-filtered claims like `department` to appear in tokens, they must be declared in the `UserClaims` collection of an `ApiScope`, `ApiResource`, or `IdentityResource`:

```csharp
new ApiScope("api1")
{
    UserClaims = { "department" }
}
```

The `tenant_id` claim does not need to be declared in `UserClaims` because it's added directly via `context.IssuedClaims.Add()`, bypassing the scope filter.

## Key Points

- **`context.AddRequestedClaims(claims)`** filters your claims to only those whose types are in `context.RequestedClaimTypes` (derived from requested scopes). Use this for opt-in claims.
- **`context.IssuedClaims.Add(claim)`** bypasses all filtering — use this for mandatory claims like `tenant_id` that must always be in every token.
- **`IsActiveAsync`** is called on token issuance and refresh token redemption to verify the user is still active.
- **Extend `DefaultProfileService`** rather than implementing `IProfileService` directly — `DefaultProfileService` provides sensible defaults for the base behavior.
