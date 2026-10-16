# Differentiating identity vs access token in IProfileService

Check `context.Caller`:

```csharp
public async Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var user = await users.FindBySubjectIdAsync(context.Subject.GetSubjectId());
    if (user is null) return;

    switch (context.Caller)
    {
        case IdentityServerConstants.ProfileDataCallers.ClaimsProviderIdentityToken:
            context.AddRequestedClaims(new[] { new Claim("name", user.Name) });
            break;

        case IdentityServerConstants.ProfileDataCallers.ClaimsProviderAccessToken:
            context.AddRequestedClaims(new[]
            {
                new Claim("department", user.Department),
                new Claim("tenant_id", user.TenantId),
                new Claim("app_role", user.AppRole),
            });
            break;

        case IdentityServerConstants.ProfileDataCallers.UserInfoEndpoint:
            context.AddRequestedClaims(new[] { new Claim("name", user.Name), new Claim("email", user.Email) });
            break;
    }
}

public Task IsActiveAsync(IsActiveContext context) { context.IsActive = true; return Task.CompletedTask; }
```
Register: `.AddProfileService<AppProfileService>()`.

Other callers: `UserInfoEndpoint`, `ClaimsProviderIdentityToken`, `ClaimsProviderAccessToken`.

## Declare the claims
`AddRequestedClaims` filters by requested claim types, so declare them:
```csharp
new ApiScope("api1", "My API") { UserClaims = { "department", "tenant_id", "app_role" } },
new IdentityResources.Profile()   // includes "name"
```
`context.RequestedClaimTypes` is for access tokens built from scopes/resources, and for identity tokens from identity resources. Also, ID tokens only contain user claims when `AlwaysIncludeUserClaimsInIdToken` is true or no access token is issued; otherwise they come from userinfo.
