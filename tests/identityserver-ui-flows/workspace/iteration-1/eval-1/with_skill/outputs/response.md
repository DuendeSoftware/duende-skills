# Login Page with IIdentityServerInteractionService

Here's a complete Razor Pages login implementation for your IdentityServer.

## Pages/Login.cshtml.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Test;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

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
    public string Username { get; set; } = string.Empty;

    [BindProperty]
    public string Password { get; set; } = string.Empty;

    [BindProperty]
    public string ReturnUrl { get; set; } = string.Empty;

    public string? ClientName { get; set; }

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;

        // Use IIdentityServerInteractionService to get the authorization context
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context != null)
        {
            // Display the client name to the user
            ClientName = context.Client?.ClientName ?? context.Client?.ClientId;
        }

        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        // Validate credentials against TestUserStore
        if (_users.ValidateCredentials(Username, Password))
        {
            var user = _users.FindByUsername(Username);

            // Create an IdentityServerUser with the subject ID
            var isUser = new IdentityServerUser(user.SubjectId)
            {
                DisplayName = user.Username
            };

            // Establish the authentication session
            await HttpContext.SignInAsync(isUser);

            // Protect against open redirect attacks
            if (_interaction.IsValidReturnUrl(ReturnUrl) || Url.IsLocalUrl(ReturnUrl))
            {
                return Redirect(ReturnUrl);
            }

            return Redirect("~/");
        }

        ModelState.AddModelError(string.Empty, "Invalid username or password.");
        return Page();
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
    <p>Sign in to continue to <strong>@Model.ClientName</strong></p>
}

<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />
    
    <div asp-validation-summary="ModelOnly"></div>
    
    <div>
        <label asp-for="Username"></label>
        <input asp-for="Username" autofocus />
    </div>
    
    <div>
        <label asp-for="Password"></label>
        <input asp-for="Password" type="password" />
    </div>
    
    <button type="submit">Login</button>
</form>
```

### Key Points

1. **`IIdentityServerInteractionService`** is injected via constructor and used to call `GetAuthorizationContextAsync(returnUrl)` to retrieve the authorization context — never parse the returnUrl manually.
2. **`TestUserStore`** validates credentials with `ValidateCredentials(username, password)`.
3. **`IdentityServerUser`** is created with the user's `SubjectId` and passed to `HttpContext.SignInAsync()` to establish the authentication session.
4. **Open redirect protection**: The `returnUrl` is validated using both `_interaction.IsValidReturnUrl(ReturnUrl)` and `Url.IsLocalUrl(ReturnUrl)` before redirecting.
