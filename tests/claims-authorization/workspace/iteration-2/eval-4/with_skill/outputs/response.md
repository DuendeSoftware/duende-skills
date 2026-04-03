# Enriching ClaimsPrincipal with Application Roles via IClaimsTransformation

`IClaimsTransformation` is the right approach for adding application-specific roles from a local database after JWT validation, without putting those roles in the token itself.

## Implementation

```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Duende.IdentityModel;

public sealed class ApplicationRolesClaimsTransformation : IClaimsTransformation
{
    private readonly IApplicationRoleRepository _roles;

    public ApplicationRolesClaimsTransformation(IApplicationRoleRepository roles)
    {
        _roles = roles;
    }

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var subjectId = principal.FindFirstValue(JwtClaimTypes.Subject);
        if (subjectId is null) return principal;

        var roles = await _roles.GetRolesForUserAsync(subjectId);
        if (roles.Count == 0) return principal;

        // Create a NEW ClaimsIdentity — do NOT mutate the existing identity
        var identity = new ClaimsIdentity();
        foreach (var role in roles)
        {
            identity.AddClaim(new Claim(ClaimTypes.Role, role));
        }

        // Add the new identity to the existing principal
        principal.AddIdentity(identity);
        return principal;
    }
}
```

## Registration

Register as a transient service in your API's `Program.cs`:

```csharp
builder.Services.AddTransient<IClaimsTransformation, ApplicationRolesClaimsTransformation>();
```

## Key Points

- **Create a new `ClaimsIdentity`** and add it via `principal.AddIdentity()` — do NOT mutate the existing identity in-place with `((ClaimsIdentity)principal.Identity!).AddClaim(...)`. `ClaimsPrincipal` instances can be cached and reused, so mutating them causes subtle bugs.
- **Register as transient** — `IClaimsTransformation` runs on every authentication, so it should be transient to avoid stale data from scoped/singleton lifetimes.
- **Do NOT use `IClaimsTransformation` on the IdentityServer host** to modify token claims. `IClaimsTransformation` runs during cookie authentication/validation, not during token issuance. Use `IProfileService` on the IdentityServer host instead.
- This runs after JWT validation in your API, so the roles are available in `HttpContext.User` for use with `[Authorize(Roles = "...")]` and authorization policies — but they are NOT in the token itself, which keeps the token lean.
