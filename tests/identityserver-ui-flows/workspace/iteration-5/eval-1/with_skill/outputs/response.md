# Login Page with Razor Pages

IdentityServer separates the protocol engine from the UI. When the engine needs the user to authenticate it redirects to your login page with a `returnUrl` query parameter. Your job is to authenticate the user, establish the session, and redirect back to `returnUrl` so the protocol workflow can complete.

## Key rules

- **Never parse `returnUrl` yourself.** Use `IIdentityServerInteractionService.GetAuthorizationContextAsync(returnUrl)` to safely extract the authorization request parameters (client, IdP hint, login hint, etc.).
- **Always validate `returnUrl`** before redirecting to protect against open redirect attacks — use `Url.IsLocalUrl(returnUrl)` or `_interaction.IsValidReturnUrl(returnUrl)`.
- **Establish the session with `IdentityServerUser`** (which carries the required `sub` claim) via `HttpContext.SignInAsync`.

## Pages/Account/Login.cshtml.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Test;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages.Account;

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
    public string Username { get; set; } = default!;

    [BindProperty]
    public string Password { get; set; } = default!;

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public string? ClientName { get; set; }

    public async Task<IActionResult> OnGet(string? returnUrl)
    {
        ReturnUrl = returnUrl;

        // Extract the original authorization request — do NOT parse returnUrl manually
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

        // Display the requesting client name to the user for branding/trust
        ClientName = context?.Client?.ClientName ?? context?.Client?.ClientId;

        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);

        // Validate credentials against the TestUserStore
        if (_users.ValidateCredentials(Username, Password))
        {
            var user = _users.FindByUsername(Username);

            // Establish the authentication session. IdentityServerUser carries
            // the required `sub` claim via SubjectId.
            var isUser = new IdentityServerUser(user.SubjectId)
            {
                DisplayName = user.Username
            };

            await HttpContext.SignInAsync(isUser);

            // Protect against open redirect: only redirect to a validated returnUrl
            if (Url.IsLocalUrl(ReturnUrl) || await _interaction.IsValidReturnUrl(ReturnUrl))
            {
                return Redirect(ReturnUrl!);
            }

            // No/invalid returnUrl — fall back to a safe local page
            return Redirect("~/");
        }

        ModelState.AddModelError(string.Empty, "Invalid username or password");
        ClientName = context?.Client?.ClientName ?? context?.Client?.ClientId;
        return Page();
    }
}
```

## Pages/Account/Login.cshtml

```html
@page
@model IdentityServer.Pages.Account.LoginModel

<h1>Sign in</h1>
@if (!string.IsNullOrEmpty(Model.ClientName))
{
    <p>to continue to <strong>@Model.ClientName</strong></p>
}

<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />
    <div asp-validation-summary="All"></div>
    <label>Username <input asp-for="Username" /></label>
    <label>Password <input asp-for="Password" type="password" /></label>
    <button type="submit">Login</button>
</form>
```

## Program.cs — register the login URL and TestUserStore

`AddTestUsers` already registers the `TestUserStore` in DI, so it can be injected directly. Point IdentityServer at the login page:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LoginUrl = "/Account/Login";
})
// ...existing configuration...
.AddTestUsers(new List<Duende.IdentityServer.Test.TestUser>
{
    new Duende.IdentityServer.Test.TestUser
    {
        SubjectId = "1",
        Username = "alice",
        Password = "password"
    }
});
```

You also need the cookie handler middleware in the pipeline (`app.UseAuthentication()` is added by `UseIdentityServer()`), and `LoginPath` on the cookie handler should match `/Account/Login` if you rely on inference instead of the explicit `LoginUrl`.

## Flow summary

1. `OnGet` → `GetAuthorizationContextAsync(returnUrl)` → show client name.
2. `OnPost` → `TestUserStore.ValidateCredentials` → build `IdentityServerUser(subjectId)` → `HttpContext.SignInAsync`.
3. Validate `returnUrl` with `Url.IsLocalUrl` / `IsValidReturnUrl` → `Redirect(returnUrl)` so the browser re-issues the original authorize request and IdentityServer completes the protocol.
