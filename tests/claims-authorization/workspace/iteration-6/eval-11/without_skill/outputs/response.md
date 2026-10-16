# Stale claims on refresh

## Default behavior
By default, when a refresh token is redeemed, IdentityServer reuses the claims stored at the original sign-in/grant. Client property `UpdateAccessTokenClaimsOnRefresh` defaults to `false`, so a user who lost a role keeps it in refreshed access tokens until the refresh token expires or is revoked.

## Fix
```csharp
new Client
{
    ClientId = "interactive",
    AllowOfflineAccess = true,
    AllowedScopes = { "openid", "profile", "api1", "offline_access" },
    UpdateAccessTokenClaimsOnRefresh = true,
    AbsoluteRefreshTokenLifetime = 8 * 3600,
    SlidingRefreshTokenLifetime = 900,
    RefreshTokenExpiration = TokenExpiration.Sliding,
}
```
With this, IdentityServer calls your `IProfileService.GetProfileDataAsync` again during refresh, so it can read current roles from the database.

## Profile service
```csharp
public async Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var user = await users.FindBySubjectIdAsync(context.Subject.GetSubjectId());
    var roles = await users.GetRolesAsync(user.Id);
    context.AddRequestedClaims(roles.Select(r => new Claim("role", r)));
}

public async Task IsActiveAsync(IsActiveContext context)
{
    var user = await users.FindBySubjectIdAsync(context.Subject.GetSubjectId());
    context.IsActive = user is { IsEnabled: true };   // false => refresh rejected
}
```
`IsActiveAsync` is called during refresh, so disabled users can't refresh.

## Other mitigations
- Short access token lifetime and short sliding refresh token lifetime.
- Revoke refresh tokens (`IPersistedGrantService.RemoveAllGrantsAsync(sub, clientId)`) when roles change.
- Have the API check roles from its own DB if immediacy matters.
- `role` must be in `UserClaims` of the ApiScope/ApiResource for it to appear.
