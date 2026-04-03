# ASP.NET Identity Integration with IdentityServer

## Updated Program.cs

```csharp
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Configure ASP.NET Identity
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// Configure IdentityServer with ASP.NET Identity integration
builder.Services.AddIdentityServer()
    .AddAspNetIdentity<ApplicationUser>();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## What `AddAspNetIdentity<ApplicationUser>()` Does

`AddAspNetIdentity<TUser>` registers several IdentityServer-specific implementations:

- **`IProfileService`** — Uses `IUserClaimsPrincipalFactory` to add claims from the ASP.NET Identity user to tokens. This is how user claims get included in identity tokens and access tokens.
- **`IResourceOwnerPasswordValidator`** — Supports the password grant type using ASP.NET Identity's user store.
- **`IUserClaimsPrincipalFactory`** wrapper — Calls through to the previously registered factory and adds extra IdentityServer-specific claims.

## Key Points

1. Call `AddIdentity<ApplicationUser, IdentityRole>()` with `AddEntityFrameworkStores<ApplicationDbContext>()` and `AddDefaultTokenProviders()`.
2. Call `AddIdentityServer().AddAspNetIdentity<ApplicationUser>()` to bridge ASP.NET Identity to IdentityServer.
3. `AddAspNetIdentity` registers `IProfileService` which is responsible for adding claims to tokens.
4. `AddDefaultTokenProviders()` is required for password reset, email confirmation, etc.
