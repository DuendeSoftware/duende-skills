# Login Page with IIdentityServerInteractionService

Here's a Razor Pages login page that uses `IIdentityServerInteractionService` to get the authorization context, validates credentials against `TestUserStore`, establishes the authentication session with `IdentityServerUser`, and protects against open redirect attacks.

## Pages/Login.cshtml

```cshtml
@page
@model LoginModel

<h1>Login</h1>
<p>Sign in to <strong>@Model.ClientName</strong></p>

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
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.ComponentModel.DataAnnotations;

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

    public string ClientName { get; set; }

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;

        // Use IIdentityServerInteractionService to get the authorization context
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context != null)
        {
            ClientName = context.Client.ClientName ?? context.Client.ClientId;
        }

        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        // Validate credentials using TestUserStore
        if (_userStore.ValidateCredentials(Username, Password))
        {
            var user = _userStore.FindByUsername(Username);

            // Create an IdentityServerUser with the subject ID and sign in
            var isUser = new IdentityServerUser(user.SubjectId)
            {
                DisplayName = user.Username
            };

            await HttpContext.SignInAsync(isUser);

            // Validate returnUrl before redirecting to protect against open redirects
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

## Key Points

1. **IIdentityServerInteractionService injection**: The login page model injects `IIdentityServerInteractionService` via the constructor and uses it to retrieve the authorization context.

2. **GetAuthorizationContextAsync**: Called with the `returnUrl` to extract the original authorization request parameters, including the client name for display.

3. **IdentityServerUser + SignInAsync**: After credential validation, an `IdentityServerUser` is created with the user's `SubjectId` and the session is established via `HttpContext.SignInAsync`.

4. **Open redirect protection**: The `returnUrl` is validated using both `_interaction.IsValidReturnUrl` and `Url.IsLocalUrl` before redirecting, preventing open redirect attacks.
