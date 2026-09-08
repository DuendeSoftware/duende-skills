# Enriching the `ClaimsPrincipal` in your API with local roles

Since these roles must **not** live in the token, don't touch `IProfileService` on IdentityServer. The right tool is **`IClaimsTransformation`**, an ASP.NET Core interface that runs in the consuming API *after* the token is validated but *before* authorization. It augments the in-memory `ClaimsPrincipal` for the current request only — nothing is written back into the JWT.

## Implementation

```csharp
using Microsoft.AspNetCore.Authentication;
using Duende.IdentityModel; // JwtClaimTypes
using System.Security.Claims;

public sealed class ApplicationRoleClaimsTransformation : IClaimsTransformation
{
    private readonly IAppRoleRepository _roles;

    public ApplicationRoleClaimsTransformation(IAppRoleRepository roles)
    {
        _roles = roles;
    }

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        // Identify the user from the validated token's subject claim.
        var subjectId = principal.FindFirstValue(JwtClaimTypes.Subject);
        if (subjectId is null)
        {
            return principal;
        }

        // Load application-specific roles from the local database.
        var appRoles = await _roles.GetRolesForUserAsync(subjectId);

        // IMPORTANT: never mutate the existing identity in place — a
        // ClaimsPrincipal can be cached/reused across requests. Add a NEW
        // identity to the principal instead.
        var identity = new ClaimsIdentity();
        foreach (var role in appRoles)
        {
            identity.AddClaim(new Claim(ClaimTypes.Role, role));
        }

        principal.AddIdentity(identity);
        return principal;
    }
}
```

Why the new `ClaimsIdentity`: ASP.NET Core may reuse the same `ClaimsPrincipal` instance across requests, and `TransformAsync` can be invoked more than once per request. Mutating the existing identity risks duplicated/leaking claims. Creating a fresh identity and calling `principal.AddIdentity(identity)` is the safe pattern. (If your lookup is expensive, also guard with a check so you don't re-add on repeated invocations.)

## Registration

Register it as a transient service in the API:

```csharp
// Program.cs (API)
builder.Services.AddScoped<IAppRoleRepository, AppRoleRepository>();
builder.Services.AddTransient<IClaimsTransformation, ApplicationRoleClaimsTransformation>();
```

## Important caveat

Use `IClaimsTransformation` **only in the consuming API (or web app)** — never on the IdentityServer host to change what goes into tokens. On the IdentityServer host `IClaimsTransformation` runs during cookie authentication, not token issuance, so it will not affect token content. If you ever *do* need those roles inside the token, that belongs in `IProfileService` on IdentityServer instead. Here, since you explicitly want the roles kept out of the token and only present at authorization time in the API, `IClaimsTransformation` is exactly right.
