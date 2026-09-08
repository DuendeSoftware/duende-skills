# Custom Claims Principal Factory + Disabling Inactive Users

## Registering the custom claims factory

Register your `CustomClaimsPrincipalFactory` **before** you call `AddAspNetIdentity`. The IdentityServer/ASP.NET Identity integration wraps whatever claims factory is already registered, so if yours is registered first, your custom claims get included and IdentityServer's own claims are added on top.

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// Register the custom factory BEFORE AddAspNetIdentity
builder.Services.AddScoped<IUserClaimsPrincipalFactory<ApplicationUser>, CustomClaimsPrincipalFactory>();

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddAspNetIdentity<ApplicationUser>();

// Use our profile service so inactive users don't get tokens
builder.Services.AddTransient<IProfileService, CustomProfileService>();

var app = builder.Build();

app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

## Disabling inactive users via IProfileService

IdentityServer calls `IProfileService.IsActiveAsync` when it decides whether to issue tokens and when validating them. Implement the profile service and check your user's active/enabled flag:

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using System.Security.Claims;

public class CustomProfileService : IProfileService
{
    private readonly UserManager<ApplicationUser> _userManager;

    public CustomProfileService(UserManager<ApplicationUser> userManager)
    {
        _userManager = userManager;
    }

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        // populate context.IssuedClaims as needed
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var sub = context.Subject.FindFirst("sub")?.Value;
        var user = await _userManager.FindByIdAsync(sub);

        // Inactive/disabled users get no tokens
        context.IsActive = user != null && user.IsActive;
    }
}
```

## Summary

- Register `CustomClaimsPrincipalFactory` as `IUserClaimsPrincipalFactory<ApplicationUser>` before `AddAspNetIdentity` so your claims are picked up.
- Register `CustomProfileService` as `IProfileService`.
- In `IsActiveAsync`, look up the user and set `context.IsActive` based on your own enabled/active property so disabled users can't obtain or keep tokens.
