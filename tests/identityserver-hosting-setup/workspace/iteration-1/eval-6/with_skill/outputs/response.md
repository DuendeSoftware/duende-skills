# Custom Claims Factory and Inactive User Handling

## Program.cs

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Register ASP.NET Identity
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// Register the custom claims principal factory BEFORE AddAspNetIdentity
builder.Services.AddScoped<IUserClaimsPrincipalFactory<ApplicationUser>,
    CustomClaimsPrincipalFactory>();

// Register IdentityServer with ASP.NET Identity bridge
builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddAspNetIdentity<ApplicationUser>();

// Register the custom profile service to handle inactive users
builder.Services.AddTransient<Duende.IdentityServer.Services.IProfileService,
    CustomProfileService>();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();
app.Run();
```

## Custom Claims Principal Factory

```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;

public class CustomClaimsPrincipalFactory
    : UserClaimsPrincipalFactory<ApplicationUser, IdentityRole>
{
    public CustomClaimsPrincipalFactory(
        UserManager<ApplicationUser> userManager,
        RoleManager<IdentityRole> roleManager,
        IOptions<IdentityOptions> options)
        : base(userManager, roleManager, options)
    { }

    protected override async Task<ClaimsIdentity> GenerateClaimsAsync(
        ApplicationUser user)
    {
        var identity = await base.GenerateClaimsAsync(user);

        // Add custom claims
        identity.AddClaim(new Claim("department", user.Department ?? ""));
        identity.AddClaim(new Claim("employee_id", user.EmployeeId ?? ""));

        return identity;
    }
}
```

## Custom Profile Service for Inactive Users

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
        // Check the user's active/enabled status
        return Task.FromResult(user.IsActive);
    }
}
```

## How It All Fits Together

### Registration Order Matters

1. **Register `CustomClaimsPrincipalFactory` BEFORE `AddAspNetIdentity`** — When `AddAspNetIdentity<ApplicationUser>()` is called, it resolves the currently registered `IUserClaimsPrincipalFactory<ApplicationUser>` and wraps it. If you register your custom factory first, IdentityServer will call through to it when building claims.

2. **`AddAspNetIdentity<ApplicationUser>()`** bridges ASP.NET Identity to IdentityServer. It registers the default `ProfileService<ApplicationUser>` which uses the claims factory to build token claims.

3. **Register `CustomProfileService` as `IProfileService` AFTER `AddAspNetIdentity`** — This replaces the default profile service with your custom one that overrides `IsUserActiveAsync`.

### IsUserActiveAsync Behavior

The `IsUserActiveAsync` method is called by IdentityServer during:
- Token issuance (both access and identity tokens)
- Token refresh
- UserInfo endpoint requests

When it returns `false`, IdentityServer treats the user as inactive and denies token issuance. The `ApplicationUser.IsActive` property should be a boolean field on your user entity that administrators can toggle.
