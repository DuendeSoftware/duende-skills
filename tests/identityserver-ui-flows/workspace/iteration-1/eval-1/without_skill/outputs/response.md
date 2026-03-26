# Login Page for IdentityServer

Here's how to build a login page using Razor Pages for your IdentityServer setup.

## Login.cshtml.cs

```csharp
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Test;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Security.Claims;

namespace IdentityServer.Pages;

public class LoginModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly TestUserStore _users;

    public LoginModel(
        IIdentityServerInteractionService interaction,
        TestUserStore users)
    {
        _interaction = interaction;
        _users = users;
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

        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context != null)
        {
            ClientName = context.Client.ClientName;
        }

        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        if (_users.ValidateCredentials(Username, Password))
        {
            var user = _users.FindByUsername(Username);

            var claims = new List<Claim>
            {
                new Claim("sub", user.SubjectId),
                new Claim("name", user.Username)
            };

            var identity = new ClaimsIdentity(claims, "pwd");
            var principal = new ClaimsPrincipal(identity);

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
}
```

## Login.cshtml

```html
@page
@model LoginModel

<h2>Login</h2>

@if (!string.IsNullOrEmpty(Model.ClientName))
{
    <p>You are signing in to @Model.ClientName</p>
}

<form method="post">
    <div asp-validation-summary="All"></div>
    <input asp-for="Username" placeholder="Username" />
    <input asp-for="Password" type="password" placeholder="Password" />
    <input type="hidden" asp-for="ReturnUrl" />
    <button type="submit">Sign In</button>
</form>
```

This creates a basic login page. The `IIdentityServerInteractionService` is used to get information about the authorization request. After validating credentials, we create a `ClaimsPrincipal` and sign in the user. We also validate the return URL to prevent open redirect attacks.
