# Login Page for IdentityServer (Razor Pages)

Here's a Razor Pages login page that wires up the IdentityServer interaction service, validates against the test users, signs the user in, and guards against open redirects.

## Pages/Account/Login.cshtml.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Test;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class LoginModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly TestUserStore _users;

    public LoginModel(IIdentityServerInteractionService interaction, TestUserStore users)
    {
        _interaction = interaction;
        _users = users;
    }

    [BindProperty] public string Username { get; set; }
    [BindProperty] public string Password { get; set; }
    [BindProperty] public string ReturnUrl { get; set; }

    public string ClientName { get; set; }

    public async Task<IActionResult> OnGetAsync(string returnUrl)
    {
        ReturnUrl = returnUrl;

        // Get the authorization context from the returnUrl instead of parsing it
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        ClientName = context?.Client?.ClientName;

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (_users.ValidateCredentials(Username, Password))
        {
            var user = _users.FindByUsername(Username);

            // Build the IdentityServer user (subject id becomes the `sub` claim)
            var isUser = new IdentityServerUser(user.SubjectId)
            {
                DisplayName = user.Username
            };
            await HttpContext.SignInAsync(isUser);

            // Prevent open redirect attacks
            if (Url.IsLocalUrl(ReturnUrl))
            {
                return Redirect(ReturnUrl);
            }
            return RedirectToPage("/Index");
        }

        ModelState.AddModelError(string.Empty, "Invalid credentials");
        return Page();
    }
}
```

## Pages/Account/Login.cshtml

```html
@page
@model LoginModel

<h2>Login</h2>
@if (!string.IsNullOrEmpty(Model.ClientName))
{
    <p>Signing in to @Model.ClientName</p>
}

<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />
    <div asp-validation-summary="All"></div>
    <input asp-for="Username" placeholder="Username" />
    <input asp-for="Password" type="password" placeholder="Password" />
    <button type="submit">Sign in</button>
</form>
```

## Notes

- `AddTestUsers(...)` in `Program.cs` registers the `TestUserStore` in DI, so you can inject it directly.
- `GetAuthorizationContextAsync(returnUrl)` returns the parsed authorization request, which contains the requesting `Client` — use `Client.ClientName` for display.
- `IdentityServerUser` sets the `sub` claim from the subject id, which is required.
- `Url.IsLocalUrl(returnUrl)` is the standard ASP.NET Core way to block open redirects. If you want IdentityServer-aware validation, you can also use `_interaction.IsValidReturnUrl(returnUrl)`.
- Make sure your cookie authentication `LoginPath` (or `options.UserInteraction.LoginUrl`) points to `/Account/Login`.
