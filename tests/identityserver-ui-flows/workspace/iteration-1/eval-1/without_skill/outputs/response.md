# Login Page for IdentityServer

Here's how to build a login page using Razor Pages for your IdentityServer setup.

## Pages/Login.cshtml.cs

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages;

public class LoginModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public LoginModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    [BindProperty]
    public string Username { get; set; }

    [BindProperty]
    public string Password { get; set; }

    [BindProperty]
    public string ReturnUrl { get; set; }

    public string ClientName { get; set; }

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;

        // Get authorization context to display client info
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context != null)
        {
            ClientName = context.Client.ClientName;
        }

        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        // You'd validate credentials against your user store here
        // For example with ASP.NET Identity:
        // var result = await _signInManager.PasswordSignInAsync(Username, Password, false, false);

        if (IsValidUser(Username, Password))
        {
            var claims = new List<System.Security.Claims.Claim>
            {
                new System.Security.Claims.Claim("sub", "user_id_here"),
                new System.Security.Claims.Claim("name", Username)
            };

            var identity = new System.Security.Claims.ClaimsIdentity(claims, "pwd");
            var principal = new System.Security.Claims.ClaimsPrincipal(identity);

            await HttpContext.SignInAsync(principal);

            if (Url.IsLocalUrl(ReturnUrl))
            {
                return Redirect(ReturnUrl);
            }

            return Redirect("~/");
        }

        ModelState.AddModelError("", "Invalid credentials");
        return Page();
    }

    private bool IsValidUser(string username, string password)
    {
        // Implement your validation logic
        return username == "alice" && password == "password";
    }
}
```

## Pages/Login.cshtml

```html
@page
@model IdentityServer.Pages.LoginModel

<h1>Login</h1>

@if (!string.IsNullOrEmpty(Model.ClientName))
{
    <p>Sign in to <strong>@Model.ClientName</strong></p>
}

<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />
    <div asp-validation-summary="ModelOnly"></div>
    
    <div>
        <label asp-for="Username"></label>
        <input asp-for="Username" />
    </div>
    
    <div>
        <label asp-for="Password"></label>
        <input asp-for="Password" type="password" />
    </div>
    
    <button type="submit">Sign In</button>
</form>
```

### Key points

- The login page gets the authorization context from the return URL to display client information.
- After validation, a `ClaimsPrincipal` is created and `HttpContext.SignInAsync` establishes the session.
- Always validate the `returnUrl` with `Url.IsLocalUrl()` to prevent open redirect attacks.
