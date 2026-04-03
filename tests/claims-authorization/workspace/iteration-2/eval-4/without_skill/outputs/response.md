# Enriching ClaimsPrincipal with Application Roles

To add application-specific roles from a local database after JWT validation, you can use `IClaimsTransformation`.

## Implementation

```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;

public class ApplicationRolesTransformation : IClaimsTransformation
{
    private readonly IApplicationRoleRepository _roles;

    public ApplicationRolesTransformation(IApplicationRoleRepository roles)
    {
        _roles = roles;
    }

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var userId = principal.FindFirst("sub")?.Value
            ?? principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null) return principal;

        var roles = await _roles.GetRolesForUserAsync(userId);

        var clonedIdentity = (ClaimsIdentity)principal.Identity!;
        foreach (var role in roles)
        {
            clonedIdentity.AddClaim(new Claim(ClaimTypes.Role, role));
        }

        return principal;
    }
}
```

## Registration

```csharp
builder.Services.AddTransient<IClaimsTransformation, ApplicationRolesTransformation>();
```

## Notes

- `IClaimsTransformation` runs after authentication but before authorization
- The roles will be available via `User.IsInRole("admin")` or `[Authorize(Roles = "admin")]`
- This keeps the JWT token small since the roles are only added on the API side
- The transformation runs on every request, so consider caching the database lookups
