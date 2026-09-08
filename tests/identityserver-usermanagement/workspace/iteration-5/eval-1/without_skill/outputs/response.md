# Adding Passwordless Email OTP Login with SQLite to IdentityServer

I'll walk you through wiring up passwordless (email one-time-code) login for your IdentityServer host, using SQLite to persist users. Since Duende's user-management building blocks sit on top of ASP.NET Core Identity, the most common and well-supported approach is to combine **ASP.NET Core Identity** (for the user store and token generation) with your existing IdentityServer, and disable password sign-in in favor of email OTP.

## 1. NuGet Packages

```bash
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore
dotnet add package Microsoft.EntityFrameworkCore.Sqlite
dotnet add package Duende.IdentityServer.AspNetIdentity
```

`Duende.IdentityServer.AspNetIdentity` glues IdentityServer's profile/claims pipeline to ASP.NET Identity users.

## 2. DbContext and User Store

```csharp
public class AppDbContext : IdentityDbContext<IdentityUser>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
}
```

## 3. Program.cs Changes

```csharp
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("Default")
                       ?? "Data Source=users.db";

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlite(connectionString));

builder.Services.AddIdentity<IdentityUser, IdentityRole>(options =>
    {
        // Passwordless: we won't require a password on sign-in,
        // but Identity still needs a token provider for OTP codes.
        options.SignIn.RequireConfirmedEmail = true;
    })
    .AddEntityFrameworkStores<AppDbContext>()
    .AddDefaultTokenProviders();

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddAspNetIdentity<IdentityUser>();   // bridge to Identity users

builder.Services.AddRazorPages();

var app = builder.Build();

// Apply EF Core migrations / create the SQLite database
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.Migrate();
}

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## 4. Generating and Verifying the Email OTP

On your login page, generate a one-time code and email it:

```csharp
public class LoginModel : PageModel
{
    private readonly UserManager<IdentityUser> _userManager;
    private readonly IEmailSender _emailSender;

    // Send code
    public async Task<IActionResult> OnPostSendCodeAsync(string email)
    {
        var user = await _userManager.FindByEmailAsync(email)
                   ?? new IdentityUser { UserName = email, Email = email };
        if (user.Id == null) await _userManager.CreateAsync(user);

        var token = await _userManager.GenerateUserTokenAsync(
            user, TokenOptions.DefaultEmailProvider, "passwordless-auth");

        await _emailSender.SendEmailAsync(email, "Your login code", $"Code: {token}");
        return Page();
    }

    // Verify code
    public async Task<IActionResult> OnPostVerifyAsync(string email, string code)
    {
        var user = await _userManager.FindByEmailAsync(email);
        var valid = await _userManager.VerifyUserTokenAsync(
            user, TokenOptions.DefaultEmailProvider, "passwordless-auth", code);

        if (valid)
        {
            await HttpContext.SignInAsync(/* issue the auth cookie */);
            return Redirect(returnUrl);
        }
        ModelState.AddModelError("", "Invalid code");
        return Page();
    }
}
```

You'll need an `IEmailSender` implementation (SMTP, SendGrid, etc.) to deliver the code.

## 5. Create the Migration

```bash
dotnet ef migrations add InitialIdentity
dotnet ef database update
```

## Summary

- Use ASP.NET Core Identity with the EF Core **SQLite** provider for storage.
- Bridge it to IdentityServer with `AddAspNetIdentity<IdentityUser>()`.
- Generate/verify email OTP codes with `GenerateUserTokenAsync` / `VerifyUserTokenAsync` and an email sender.
- Run `dotnet ef database update` to create the SQLite schema.

This gives you passwordless email-code login while keeping IdentityServer as your OIDC/OAuth endpoint. If you're referring to a specific Duende "User Management" product with its own configuration API, check its documentation for the exact registration extension methods, as the naming may differ from the ASP.NET Identity approach shown here.
