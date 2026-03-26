# Enriching ClaimsPrincipal with API-Side Roles via IClaimsTransformation

`IClaimsTransformation` is an ASP.NET Core interface that runs **after** authentication but **before** authorization. It's the right tool for enriching the principal with application-specific data that doesn't belong in the token itself.

## Implementation

```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;

public sealed class ApplicationRoleClaimsTransformation : IClaimsTransformation
{
    private readonly IApplicationRoleRepository _roleRepository;

    public ApplicationRoleClaimsTransformation(IApplicationRoleRepository roleRepository)
    {
        _roleRepository = roleRepository;
    }

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var subjectId = principal.FindFirstValue("sub");
        if (subjectId is null)
        {
            return principal;
        }

        // Load application-specific roles from local database
        var roles = await _roleRepository.GetRolesForUserAsync(subjectId);

        // IMPORTANT: Create a NEW ClaimsIdentity and add it to the principal
        // Do NOT mutate the existing identity — ClaimsPrincipal can be reused across calls
        var identity = new ClaimsIdentity();
        foreach (var role in roles)
        {
            identity.AddClaim(new Claim("app_role", role));
        }

        principal.AddIdentity(identity);
        return principal;
    }
}
```

## Registration

```csharp
// Program.cs — in your API project
builder.Services.AddTransient<IClaimsTransformation, ApplicationRoleClaimsTransformation>();
```

## Key Points

- **Use `IClaimsTransformation` in APIs and web apps** — it runs after token validation, so the principal already has the claims from the JWT.
- **Create a new `ClaimsIdentity`** and add it via `principal.AddIdentity()`. Never mutate the existing identity with `((ClaimsIdentity)principal.Identity!).AddClaim(...)` — the principal can be cached and reused.
- **Register as `Transient`** — `TransformAsync` is called on every request, so use transient to avoid stale state.
- **Do NOT use `IClaimsTransformation` on the IdentityServer host** to modify token claims. It runs during cookie authentication, not token issuance. Use `IProfileService` on the IdentityServer side instead.
