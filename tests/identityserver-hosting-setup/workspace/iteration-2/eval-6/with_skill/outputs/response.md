# Custom Claims Factory and Profile Service

## Updated Program.cs

```csharp
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// Register CustomClaimsPrincipalFactory BEFORE AddAspNetIdentity
// AddAspNetIdentity wraps the existing factory and calls through to it
builder.Services.AddScoped<IUserClaimsPrincipalFactory<ApplicationUser>, CustomClaimsPrincipalFactory>();

builder.Services.AddIdentityServer()
    .AddAspNetIdentity<ApplicationUser>();

// Register the custom profile service to handle inactive users
builder.Services.AddTransient<Duende.IdentityServer.Services.IProfileService, CustomProfileService>();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

## CustomProfileService

```csharp
using Duende.IdentityServer.AspNetIdentity;
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
        // Check a custom property on the user to determine if they're active
        return Task.FromResult(user.IsActive);
    }
}
```

## Key Points

- Register `CustomClaimsPrincipalFactory` as `IUserClaimsPrincipalFactory<ApplicationUser>` **BEFORE** calling `AddAspNetIdentity`. The IdentityServer registration will resolve your factory and call through to it.
- `AddAspNetIdentity<ApplicationUser>()` bridges ASP.NET Identity to IdentityServer, wrapping the custom factory.
- `CustomProfileService` inherits from `ProfileService<ApplicationUser>` and overrides `IsUserActiveAsync` to check a user property (e.g., `user.IsActive`).
- The custom profile service is registered in DI as `IProfileService` to override the default.
