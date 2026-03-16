# Adding Application Roles After JWT Validation

You can use ASP.NET Core's `IClaimsTransformation` to enrich the `ClaimsPrincipal` after the JWT has been validated. This lets you add application-specific roles from your local database without putting them in the token.

## Implementation

```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;

public class ApplicationRolesTransformation : IClaimsTransformation
{
    private readonly IAppRoleRepository _roleRepo;

    public ApplicationRolesTransformation(IAppRoleRepository roleRepo)
    {
        _roleRepo = roleRepo;
    }

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var userId = principal.FindFirst("sub")?.Value;
        if (userId == null) return principal;

        var roles = await _roleRepo.GetRolesAsync(userId);

        var claimsIdentity = principal.Identity as ClaimsIdentity;
        if (claimsIdentity != null)
        {
            foreach (var role in roles)
            {
                claimsIdentity.AddClaim(new Claim(ClaimTypes.Role, role));
            }
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

- `TransformAsync` is called on every authenticated request, so consider caching the role data
- The roles will be available for `[Authorize(Roles = "Admin")]` and policy-based authorization
- This approach keeps the token lean while still providing rich authorization data
