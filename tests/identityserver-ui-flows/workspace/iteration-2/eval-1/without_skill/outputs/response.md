# Login Page for IdentityServer

Here's a Razor Pages login page for IdentityServer that authenticates users and redirects them back to the client application.

## Pages/Login.cshtml

```cshtml
@page
@model LoginModel

<h1>Login</h1>
<p>Please sign in</p>

<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />
    <div>
        <label asp-for="Username"></label>
        <input asp-for="Username" />
    </div>
    <div>
        <label asp-for="Password"></label>
        <input asp-for="Password" type="password" />
    </div>
    <span asp-validation-summary="All" class="text-danger"></span>
    <button type="submit">Login</button>
</form>
```

## Pages/Login.cshtml.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Test;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Security.Claims;

public class LoginModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly TestUserStore _userStore;

    public LoginModel(
        IIdentityServerInteractionService interaction,
        TestUserStore userStore)
    {
        _interaction = interaction;
        _userStore = userStore;
    }

    [BindProperty]
    public string Username { get; set; }

    [BindProperty]
    public string Password { get; set; }

    [BindProperty]
    public string ReturnUrl { get; set; }

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;
        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        if (_userStore.ValidateCredentials(Username, Password))
        {
            var user = _userStore.FindByUsername(Username);

            var claims = new List<Claim>
            {
                new Claim("sub", user.SubjectId),
                new Claim("name", user.Username)
            };
            var identity = new ClaimsIdentity(claims, "pwd");
            var principal = new ClaimsPrincipal(identity);

            await HttpContext.SignInAsync(principal);

            if (!string.IsNullOrEmpty(ReturnUrl))
            {
                return Redirect(ReturnUrl);
            }

            return Redirect("~/");
        }

        ModelState.AddModelError(string.Empty, "Invalid credentials.");
        return Page();
    }
}
```

## Notes

- The login page uses `TestUserStore` to validate credentials
- After successful login, it creates a `ClaimsPrincipal` with the user's subject ID and signs in
- The `returnUrl` is used to redirect the user back to where they came from
