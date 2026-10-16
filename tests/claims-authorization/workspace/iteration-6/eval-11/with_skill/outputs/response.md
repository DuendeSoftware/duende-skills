# Stale roles after refresh token redemption

## Default
`Client.UpdateAccessTokenClaimsOnRefresh` defaults to **`false`**. On refresh the original claims are reused and only `IProfileService.IsActiveAsync` is called. `GetProfileDataAsync` isn't re-run, so a user who lost a role keeps it until the refresh token expires/is revoked.

## Fix
```csharp
new Client
{
    ClientId = "interactive",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    AllowOfflineAccess = true,
    AllowedScopes = { "openid", "profile", "api1", "offline_access" },

    // Re-run IProfileService.GetProfileDataAsync on refresh
    UpdateAccessTokenClaimsOnRefresh = true,
}
```

## Profile service loading roles dynamically
```csharp
public sealed class DynamicProfileService(IUserPermissionService permissions, ILogger<DynamicProfileService> logger)
    : DefaultProfileService(logger)
{
    public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var sub = context.Subject.GetSubjectId();
        var roles = await permissions.GetRolesAsync(sub);
        context.AddRequestedClaims(roles.Select(r => new Claim(JwtClaimTypes.Role, r)));
    }

    public override async Task IsActiveAsync(IsActiveContext context)
        => context.IsActive = await permissions.IsUserActiveAsync(context.Subject.GetSubjectId());
}
```
Remember `role` must be in the `UserClaims` of the ApiScope/ApiResource (e.g. `new ApiScope("api1") { UserClaims = { "role" } }`), otherwise `AddRequestedClaims` filters it out.

## Caveats
- Since `GetProfileDataAsync` now runs on every refresh, cache lookups (`IMemoryCache`, key `subject+client`, TTL shorter than access token lifetime). A long cache TTL reintroduces staleness.
- `IsActiveAsync` (with `context.Caller == ProfileIsActiveCallers.RefreshTokenValidation`) lets you reject disabled users. If you deactivate, also revoke persisted grants so users don't see opaque failures.
- Keep access token lifetimes short as extra protection.
