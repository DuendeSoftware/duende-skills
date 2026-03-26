# Adding Application Roles to ClaimsPrincipal After JWT Validation

You can use `IClaimsTransformation` to enrich the principal with additional claims from your local database.

## Implementation

```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;

public class RoleClaimsTransformation : IClaimsTransformation
{
    private readonly IRoleService _roleService;

    public RoleClaimsTransformation(IRoleService roleService)
    {
        _roleService = roleService;
    }

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var userId = principal.FindFirst("sub")?.Value;
        if (userId == null) return principal;

        var roles = await _roleService.GetRolesAsync(userId);

        var claimsIdentity = (ClaimsIdentity)principal.Identity!;
        foreach (var role in roles)
        {
            claimsIdentity.AddClaim(new Claim(ClaimTypes.Role, role));
        }

        return principal;
    }
}
```

## Registration

```csharp
builder.Services.AddTransient<IClaimsTransformation, RoleClaimsTransformation>();
```

This will add the roles from your database to the user's claims after the JWT is validated. The roles will then be available for authorization policies.
