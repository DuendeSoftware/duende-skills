# Getting User Claims into Tokens with IdentityServer

To include user claims in ID tokens with Duende IdentityServer, you need to implement `IProfileService` and configure your identity resources.

## 1. Implement IProfileService

```csharp
public class CustomProfileService : IProfileService
{
    private readonly IUserStore _userStore;

    public CustomProfileService(IUserStore userStore)
    {
        _userStore = userStore;
    }

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var userId = context.Subject.GetSubjectId();
        var user = await _userStore.FindByIdAsync(userId);

        var claims = new List<Claim>
        {
            new Claim("email", user.Email),
            new Claim("email_verified", user.EmailVerified.ToString().ToLower()),
            new Claim("name", user.DisplayName)
        };

        // Add custom attributes
        if (user.CustomAttributes != null)
        {
            foreach (var attr in user.CustomAttributes)
            {
                claims.Add(new Claim(attr.Key, attr.Value));
            }
        }

        context.IssuedClaims.AddRange(
            claims.Where(c => context.RequestedClaimTypes.Contains(c.Type)));
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = true;
    }
}
```

## 2. Register the Profile Service

```csharp
builder.Services.AddIdentityServer()
    .AddProfileService<CustomProfileService>()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources);
```

## 3. Define Identity Resources

```csharp
public static IEnumerable<IdentityResource> IdentityResources =>
[
    new IdentityResources.OpenId(),
    new IdentityResources.Profile(),
    new IdentityResources.Email(),
    new IdentityResource("custom", new[] { "department", "employee_id" })
];
```

## 4. Client Configuration

Ensure your client requests the appropriate scopes:

```csharp
AllowedScopes = { "openid", "profile", "email", "custom" }
```

## Notes

- Claims are only included if the client requests the corresponding scope.
- `AlwaysIncludeUserClaimsInIdToken = true` on the client will put claims directly in the ID token rather than requiring a userinfo endpoint call.
