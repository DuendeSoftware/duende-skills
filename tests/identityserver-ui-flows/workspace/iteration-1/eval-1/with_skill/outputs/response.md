# Login Page Implementation for IdentityServer

Here's a complete Razor Pages implementation for the login page that uses `IIdentityServerInteractionService` and `TestUserStore`.

## Login.cshtml.cs (Page Model)

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
    private readonly TestUserStore _userStore;

    public LoginModel(
        IIdentityServerInteractionService interaction,
        TestUserStore userStore)
    {
        _interaction = interaction;
        _userStore = userStore;
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
            // Display the client name to the user for branding
            ClientName = context.Client?.ClientName ?? context.Client?.ClientId;
        }

        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        // Validate credentials against TestUserStore
        if (_userStore.ValidateCredentials(Username, Password))
        {
            var user = _userStore.FindByUsername(Username);

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

## Login.cshtml (Razor View)

```html
@page
@model IdentityServer.Pages.LoginModel

<h1>Login</h1>

@if (!string.IsNullOrEmpty(Model.ClientName))
{
    <p>Sign in to continue to <strong>@Model.ClientName</strong></p>
}

<form method="post">
    <div asp-validation-summary="ModelOnly"></div>

    <div>
        <label asp-for="Username"></label>
        <input asp-for="Username" autofocus />
    </div>

    <div>
        <label asp-for="Password"></label>
        <input asp-for="Password" type="password" />
    </div>

    <input type="hidden" asp-for="ReturnUrl" />

    <button type="submit">Login</button>
</form>
```

## Key Design Decisions

1. **Authorization Context**: The page calls `GetAuthorizationContextAsync(returnUrl)` to retrieve the authorization context rather than parsing the returnUrl manually. This is critical — the interaction service safely deserializes the return URL and gives you access to the client, requested scopes, IdP hints, and more.

2. **IdentityServerUser**: We create an `IdentityServerUser` with the user's `SubjectId` and call `HttpContext.SignInAsync()` to establish the authentication session. The `sub` claim is required and must uniquely identify the user.

3. **Open Redirect Protection**: Before redirecting back to the `returnUrl`, we validate it using both `_interaction.IsValidReturnUrl()` (which checks IdentityServer's internal URL validation) and `Url.IsLocalUrl()` as a fallback. This prevents open redirect attacks where a malicious returnUrl could send the user to an attacker-controlled site.

4. **TestUserStore**: We inject `TestUserStore` for credential validation via `ValidateCredentials()` and user lookup via `FindByUsername()`. In production, you'd replace this with ASP.NET Identity or your own user store.
