# Custom claims factory and inactive users

## Register the factory

Register your factory **before** `AddAspNetIdentity`; IdentityServer's wrapper resolves it, calls through, and layers its own claims on top.

```csharp
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// BEFORE AddAspNetIdentity
builder.Services.AddScoped<IUserClaimsPrincipalFactory<ApplicationUser>, CustomClaimsPrincipalFactory>();

builder.Services.AddIdentityServer()
    .AddAspNetIdentity<ApplicationUser>()
    .AddProfileService<CustomProfileService>();
```

`AddAspNetIdentity` registers `IProfileService` (which uses the factory to add claims to tokens), `IResourceOwnerPasswordValidator`, and the wrapping `IUserClaimsPrincipalFactory`. Remember to call both `AddIdentity` and `AddAspNetIdentity`.

## Disabling inactive users

ASP.NET Identity has no notion of inactive users; the default `IsActiveAsync` returns `true`. Subclass `ProfileService<TUser>` and override `IsUserActiveAsync`:

```csharp
public class CustomProfileService : ProfileService<ApplicationUser>
{
    public CustomProfileService(
        UserManager<ApplicationUser> userManager,
        IUserClaimsPrincipalFactory<ApplicationUser> claimsFactory)
        : base(userManager, claimsFactory)
    { }

    protected override Task<bool> IsUserActiveAsync(ApplicationUser user)
        => Task.FromResult(user.IsEnabled); // your custom property
}
```

Pipeline for reference: `UseStaticFiles` → `UseRouting` → `UseIdentityServer` → `UseAuthorization`. Also ensure the custom claims are mapped to identity resources/API scopes (`UserClaims`) so they are actually emitted.
