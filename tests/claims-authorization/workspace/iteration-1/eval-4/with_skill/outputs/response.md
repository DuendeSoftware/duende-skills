# Enriching ClaimsPrincipal with Local Roles via IClaimsTransformation

`IClaimsTransformation` is the correct ASP.NET Core interface for enriching the `ClaimsPrincipal` after JWT validation with application-specific data that doesn't belong in the token itself.

> **Important:** Do not use `IClaimsTransformation` on the IdentityServer host to modify token claims. It runs during cookie authentication, not token issuance — use `IProfileService` there instead. `IClaimsTransformation` is meant for use in APIs and web apps that consume tokens.

## Implementation

```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;

public sealed class ApplicationRolesClaimsTransformation : IClaimsTransformation
{
    private readonly IApplicationRoleRepository _roleRepository;

    public ApplicationRolesClaimsTransformation(IApplicationRoleRepository roleRepository)
    {
        _roleRepository = roleRepository;
    }

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        // Get the user's subject from the token
        var subjectId = principal.FindFirstValue("sub");
        if (subjectId is null)
        {
            return principal;
        }

        // Load application-specific roles from the local database
        var roles = await _roleRepository.GetRolesForUserAsync(subjectId);
        if (roles is null || roles.Count == 0)
        {
            return principal;
        }

        // Create a NEW ClaimsIdentity and add it to the principal.
        // Do NOT mutate the existing identity — ClaimsPrincipal can be cached/reused.
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

## Registration

Register the transformation as a **transient** service in your API's `Program.cs`:

```csharp
// Program.cs — in the API project
builder.Services.AddTransient<IClaimsTransformation, ApplicationRolesClaimsTransformation>();
```

## Key Points

- **Create a new `ClaimsIdentity`** and add it via `principal.AddIdentity()` — never mutate the existing identity in-place (e.g. don't do `((ClaimsIdentity)principal.Identity!).AddClaim(...)`) because `ClaimsPrincipal` instances can be cached and reused across requests.
- **TransformAsync is called on every request** — use caching if the role lookup is expensive.
- **Do not use `IClaimsTransformation` on the IdentityServer host** for modifying token claims. It runs during cookie sign-in/validation and does not affect token content. Use `IProfileService` on the IdentityServer host instead.
- The roles added here are available in `[Authorize(Roles = "...")]` and authorization policies, just like roles from the token.
