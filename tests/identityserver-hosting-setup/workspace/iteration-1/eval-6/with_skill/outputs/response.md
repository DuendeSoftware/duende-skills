# Custom Claims Factory and Inactive User Handling

Here's how to register a custom `IUserClaimsPrincipalFactory<ApplicationUser>` and implement `IsActiveAsync` to disable tokens for inactive users.

## Updated Program.cs

```csharp
using Microsoft.AspNetCore.Identity;
using Duende.IdentityServer.AspNetIdentity;

var builder = WebApplication.CreateBuilder(args);

// Register ASP.NET Identity
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// Register custom factory BEFORE AddAspNetIdentity so it gets wrapped
builder.Services.AddScoped<IUserClaimsPrincipalFactory<ApplicationUser>, CustomClaimsPrincipalFactory>();

// Configure IdentityServer with ASP.NET Identity bridge
builder.Services.AddIdentityServer()
    .AddAspNetIdentity<ApplicationUser>();

// Register CustomProfileService as the IProfileService implementation
builder.Services.AddTransient<Duende.IdentityServer.Services.IProfileService, CustomProfileService>();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();
app.Run();
```

## CustomProfileService

```csharp
using Duende.IdentityServer.AspNetIdentity;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Identity;

public class CustomProfileService : ProfileService<ApplicationUser>
{
    public CustomProfileService(
        UserManager<ApplicationUser> userManager,
        IUserClaimsPrincipalFactory<ApplicationUser> claimsFactory)
        : base(userManager, claimsFactory)
    { }

    protected override Task<bool> IsUserActiveAsync(ApplicationUser user)
    {
        // Check custom property on user to determine if they are active
        return Task.FromResult(user.IsActive);
    }
}
```

## How It Works

1. **`CustomClaimsPrincipalFactory`** is registered as `IUserClaimsPrincipalFactory<ApplicationUser>` **before** calling `AddAspNetIdentity`. When `AddAspNetIdentity` registers its own wrapper, it resolves and calls through to your custom factory, layering additional IdentityServer-specific claims on top.

2. **`AddAspNetIdentity<ApplicationUser>()`** bridges ASP.NET Identity to IdentityServer. It registers `IProfileService` (which uses `IUserClaimsPrincipalFactory`) and other services.

3. **`CustomProfileService`** inherits from `ProfileService<ApplicationUser>` and overrides `IsUserActiveAsync`. This is called during token issuance and refresh to check whether the user should still be able to receive tokens. If `IsUserActiveAsync` returns `false`, the token request is rejected.

4. The `CustomProfileService` is registered as the `IProfileService` implementation, replacing the default one from `AddAspNetIdentity`.
