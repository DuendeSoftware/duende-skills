# Different claims for id_token vs access token

Use `context.Caller` in `GetProfileDataAsync`.

```csharp
public sealed class ApplicationProfileService(IUserRepository users, ILogger<ApplicationProfileService> logger)
    : DefaultProfileService(logger)
{
    public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var user = await users.FindBySubjectIdAsync(context.Subject.GetSubjectId());
        if (user is null) return;

        if (context.Caller == IdentityServerConstants.ProfileDataCallers.ClaimsProviderIdentityToken)
        {
            // id_token: small, just the name
            context.IssuedClaims.Add(new Claim(JwtClaimTypes.Name, user.DisplayName));
            return;
        }

        // Access token and userinfo: richer application claims, filtered by requested scopes
        context.AddRequestedClaims(new[]
        {
            new Claim(JwtClaimTypes.Name, user.DisplayName),
            new Claim("department", user.Department),
            new Claim("tenant_id", user.TenantId),
            new Claim("subscription_tier", user.SubscriptionTier),
        });
    }

    public override async Task IsActiveAsync(IsActiveContext context)
    {
        var user = await users.FindBySubjectIdAsync(context.Subject.GetSubjectId());
        context.IsActive = user is { IsEnabled: true };
    }
}
```

Callers: `ClaimsProviderIdentityToken`, `ClaimsProviderAccessToken`, `UserInfoEndpoint`.

## Register and declare claims
```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddProfileService<ApplicationProfileService>();

new ApiScope("api1", "My API") { UserClaims = { "department", "tenant_id", "subscription_tier" } }
```
`AddRequestedClaims` drops anything not in `UserClaims` of a requested resource, so the access-token claims must be declared on the `ApiScope`/`ApiResource`. `name` comes via the `profile` IdentityResource.

## Caveats
- With code flow, the id_token is minimal by default (`includeAllIdentityClaims = false`); profile claims like `name` normally arrive via userinfo (`GetClaimsFromUserInfoEndpoint = true`). Set `AlwaysIncludeUserClaimsInIdToken = true` only if you really need `name` embedded in the id_token.
- Userinfo `Subject` comes from the access token, so load data from the DB by subject id.
- Cache expensive lookups; the service runs per token issuance.
