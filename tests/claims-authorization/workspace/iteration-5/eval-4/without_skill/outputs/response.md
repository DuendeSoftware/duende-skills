# Enriching the `ClaimsPrincipal` after JWT validation

If the roles shouldn't be in the token, the cleanest place to add them is `IClaimsTransformation`. It's an ASP.NET Core interface that runs after authentication succeeds (i.e. after the JWT is validated) and before authorization, so it's perfect for adding application-specific claims computed from a local data source on each request.

## Implement `IClaimsTransformation`

```csharp
using Microsoft.AspNetCore.Authentication;
using System.Security.Claims;

public class RoleClaimsTransformation : IClaimsTransformation
{
    private readonly IUserRoleRepository _roles;

    public RoleClaimsTransformation(IUserRoleRepository roles)
    {
        _roles = roles;
    }

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var sub = principal.FindFirstValue("sub")
                  ?? principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (sub is null)
        {
            return principal;
        }

        var roles = await _roles.GetRolesAsync(sub);

        // Add the roles on a new identity rather than modifying the existing one.
        // ClaimsPrincipal instances can be reused, so mutating in place can cause
        // duplicate claims across requests.
        var identity = new ClaimsIdentity();
        foreach (var role in roles)
        {
            identity.AddClaim(new Claim(ClaimTypes.Role, role));
        }

        principal.AddIdentity(identity);
        return principal;
    }
}
```

## Register it

`IClaimsTransformation` implementations are typically registered as transient because `TransformAsync` runs per request:

```csharp
builder.Services.AddScoped<IUserRoleRepository, UserRoleRepository>();
builder.Services.AddTransient<IClaimsTransformation, RoleClaimsTransformation>();
```

## Notes

- The roles are only added to the runtime `ClaimsPrincipal` — nothing is written back to the JWT, which is exactly what you want.
- Look the user up by the `sub` (subject) claim from the validated token.
- Because `TransformAsync` can be called multiple times for the same principal, consider checking whether you've already added the identity/claims before adding them again if that matters for your logic.
- Once added, the roles participate in `[Authorize(Roles = "...")]` and policy checks just like any other claim (as long as your role claim type matches what the authorization system expects).
