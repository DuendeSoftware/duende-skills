# Adding Azure AD as an External Provider

Here's how to integrate Azure AD as an external identity provider in your IdentityServer project.

## Program.cs — Register the OpenID Connect Handler

```csharp
using Microsoft.AspNetCore.Authentication.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

builder.Services.AddIdentityServer(options => { })
    // ... existing configuration ...
    ;

// Add Azure AD as external provider
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", options =>
    {
        options.Authority = "https://login.microsoftonline.com/{tenant-id}/v2.0";
        options.ClientId = "your-client-id";
        options.ClientSecret = "your-client-secret";
        options.ResponseType = "code";
        options.CallbackPath = "/signin-aad";
    });

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Pages/ExternalLogin.cshtml.cs — Trigger the External Login

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages;

public class ExternalLoginModel : PageModel
{
    public IActionResult OnGet(string provider, string returnUrl)
    {
        var props = new AuthenticationProperties
        {
            RedirectUri = Url.Page("/ExternalLoginCallback"),
            Items = { { "returnUrl", returnUrl } }
        };

        return Challenge(props, provider);
    }
}
```

## Pages/ExternalLoginCallback.cshtml.cs — Handle the Callback

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Security.Claims;

namespace IdentityServer.Pages;

public class ExternalLoginCallbackModel : PageModel
{
    public async Task<IActionResult> OnGet()
    {
        // Read external identity from the cookie
        var result = await HttpContext.AuthenticateAsync("ExternalCookie");

        if (result?.Succeeded != true)
            throw new Exception("External authentication failed");

        var externalUser = result.Principal;
        var returnUrl = result.Properties?.Items["returnUrl"] ?? "~/";

        // Find or create local user
        var userId = externalUser.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        // Sign in locally
        var claims = new List<Claim>
        {
            new Claim("sub", userId ?? Guid.NewGuid().ToString()),
            new Claim("name", externalUser.FindFirst("name")?.Value ?? "User")
        };
        var identity = new ClaimsIdentity(claims, "external");
        var principal = new ClaimsPrincipal(identity);
        await HttpContext.SignInAsync(principal);

        // Clean up external cookie
        await HttpContext.SignOutAsync("ExternalCookie");

        return Redirect(returnUrl);
    }
}
```

### Notes

- Register the AAD provider with `AddOpenIdConnect` using the `"AAD"` scheme name.
- Store the `returnUrl` in `AuthenticationProperties.Items` so it survives the external redirect.
- After callback, clean up the external authentication cookie.
- The external user should be mapped to a local user in your database.
