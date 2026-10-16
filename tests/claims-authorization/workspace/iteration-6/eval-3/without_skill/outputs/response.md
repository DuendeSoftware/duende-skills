# `department` never reaches the access token

Emitting it from `IProfileService` isn't enough. IdentityServer filters claims by what the requested resources declare.

## Cause
In `GetProfileDataAsync`, `context.RequestedClaimTypes` is built from the `UserClaims` of the requested scopes/resources. `context.AddRequestedClaims(claims)` drops anything not listed. In your config, `api1` has no `UserClaims`.

## Fix
```csharp
public static IEnumerable<ApiScope> ApiScopes =>
[
    new ApiScope("api1", "My API") { UserClaims = { "department" } }
];
```
(or on an `ApiResource` containing the scope: `new ApiResource("my-api") { Scopes = { "api1" }, UserClaims = { "department" } }`).

Then ensure the profile service is registered and the claim comes through:
```csharp
.AddProfileService<AppProfileService>()   // and remove .AddTestUsers if not needed

public async Task GetProfileDataAsync(ProfileDataRequestContext context)
{
    var claims = new List<Claim> { new("department", dept) };
    context.AddRequestedClaims(claims);
}
```

Also check:
- The client requests scope `api1` (the claim goes in the access token, not id_token).
- Profile service is actually registered (log in it).
- If you set `context.IssuedClaims` directly, no filtering applies.
- Client credentials tokens never call the profile service for users.
- Your API may be remapping or ignoring the claim type name.
