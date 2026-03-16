# Integrating ASP.NET Identity with IdentityServer

Here's how to wire up both ASP.NET Identity and IdentityServer together:

First, install the integration package:

```bash
dotnet add package Duende.IdentityServer.AspNetIdentity
```

Then update your `Program.cs`:

```csharp
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// 1. Configure ASP.NET Identity with EF stores
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// 2. Configure IdentityServer and bridge to ASP.NET Identity
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

`AddAspNetIdentity<TUser>` registers the following IdentityServer implementations:

- **`IProfileService`** — Uses `IUserClaimsPrincipalFactory` to add claims to tokens. This is how user claims get into identity tokens and access tokens.
- **`IResourceOwnerPasswordValidator`** — Supports the password grant type (ROPC) by validating credentials against ASP.NET Identity.
- **`IUserClaimsPrincipalFactory`** — A wrapper implementation that calls through to the previously registered factory and adds extra IdentityServer-specific claims.

## Important Notes

1. **Order matters**: Call `AddIdentity<>()` before `AddIdentityServer()`. ASP.NET Identity must be registered first so IdentityServer can resolve the user manager and other services.

2. **`AddDefaultTokenProviders()`** is needed for password reset tokens, email confirmation tokens, and two-factor authentication tokens in ASP.NET Identity.

3. If you need a pre-configured template, use:
   ```bash
   dotnet new duende-is-aspid -n IdentityServer
   ```
