# Custom claims factory and IsActiveAsync

```csharp
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddClaimsPrincipalFactory<CustomClaimsPrincipalFactory>()
    .AddDefaultTokenProviders();

builder.Services.AddIdentityServer()
    .AddAspNetIdentity<ApplicationUser>();
```

Register the factory via `AddClaimsPrincipalFactory` (or `AddScoped<IUserClaimsPrincipalFactory<ApplicationUser>, ...>` after `AddIdentity`). IdentityServer's `ProfileService<TUser>` uses that factory to build claims.

**Inactive users:** subclass the profile service and override `IsActiveAsync`:

```csharp
public class CustomProfileService : ProfileService<ApplicationUser>
{
    public CustomProfileService(UserManager<ApplicationUser> userManager,
        IUserClaimsPrincipalFactory<ApplicationUser> claimsFactory)
        : base(userManager, claimsFactory) { }

    public override async Task IsActiveAsync(IsActiveContext context)
    {
        var sub = context.Subject.GetSubjectId();
        var user = await UserManager.FindByIdAsync(sub);
        context.IsActive = user != null && user.IsActive;
    }
}
```
Register after AddAspNetIdentity: `.AddProfileService<CustomProfileService>()`. Also ensure the claims are requested via scopes/resources (`UserClaims`) so they land in tokens.
