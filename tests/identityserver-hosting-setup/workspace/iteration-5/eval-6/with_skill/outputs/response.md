# Custom Claims Factory + Inactive-User Handling

Two things are needed:

1. Register your custom `IUserClaimsPrincipalFactory<ApplicationUser>` **before** `AddAspNetIdentity` so IdentityServer's wrapper resolves and calls through to it.
2. Provide a custom `ProfileService` that overrides `IsUserActiveAsync` to reject tokens for disabled users.

## Program.cs

```csharp
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Identity;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// ASP.NET Identity
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// 1. Register the custom claims factory BEFORE AddAspNetIdentity.
//    AddAspNetIdentity registers a wrapper IUserClaimsPrincipalFactory that
//    resolves the previously-registered factory and layers IdentityServer
//    claims on top — so registering yours first means your claims flow through.
builder.Services.AddScoped<IUserClaimsPrincipalFactory<ApplicationUser>, CustomClaimsPrincipalFactory>();

// IdentityServer bridged to ASP.NET Identity
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddAspNetIdentity<ApplicationUser>();

// 2. Replace the default profile service with one that gates inactive users.
//    Register AFTER AddAspNetIdentity so it wins over the default ProfileService.
builder.Services.AddTransient<IProfileService, CustomProfileService>();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## CustomProfileService.cs

`AddAspNetIdentity` registers `ProfileService<TUser>`, whose default `IsUserActiveAsync` always returns `true`. Inherit from it and override that method to check your own enabled/disabled flag:

```csharp
using Duende.IdentityServer.AspNetIdentity;
using Microsoft.AspNetCore.Identity;

public class CustomProfileService : ProfileService<ApplicationUser>
{
    public CustomProfileService(
        UserManager<ApplicationUser> userManager,
        IUserClaimsPrincipalFactory<ApplicationUser> claimsFactory)
        : base(userManager, claimsFactory)
    {
    }

    protected override Task<bool> IsUserActiveAsync(ApplicationUser user)
    {
        // Your custom property — inactive users get no tokens and existing
        // tokens fail validation at introspection/refresh time.
        return Task.FromResult(user.IsEnabled);
    }
}
```

## Why this works

- ASP.NET Identity has **no built-in concept of an inactive user** — the base `IsUserActiveAsync` returns `true` for everyone. Overriding it lets IdentityServer refuse tokens (and reject refresh/validation) for disabled accounts.
- Because `CustomProfileService` inherits from `ProfileService<ApplicationUser>`, it keeps the default claim-population behavior (which itself uses your `CustomClaimsPrincipalFactory`) and only changes the active check.
- Registering `CustomClaimsPrincipalFactory` **before** `AddAspNetIdentity`, and `CustomProfileService` as `IProfileService`, ensures both your custom claims and your active-user logic are in effect.
