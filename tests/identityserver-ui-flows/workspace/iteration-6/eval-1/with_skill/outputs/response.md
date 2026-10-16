# Login page (Razor Pages)

## Program.cs
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LoginUrl = "/Account/Login";   // explicit; otherwise inferred from cookie LoginPath
})
```
`AddTestUsers(...)` already registers `TestUserStore`, which we inject.

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
    { _interaction = interaction; _users = users; }

    [BindProperty] public string? Username { get; set; }
    [BindProperty] public string? Password { get; set; }
    [BindProperty] public string? ReturnUrl { get; set; }
    public string? ClientName { get; set; }

    public async Task<IActionResult> OnGet(string? returnUrl)
    {
        ReturnUrl = returnUrl;
        // Never parse returnUrl yourself – use the interaction service
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        ClientName = context?.Client.ClientName ?? context?.Client.ClientId;
        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        ClientName = context?.Client.ClientName ?? context?.Client.ClientId;

        if (_users.ValidateCredentials(Username, Password))
        {
            var user = _users.FindByUsername(Username);

            // Establish the IdentityServer session (sub is required)
            var isuser = new IdentityServerUser(user.SubjectId)
            {
                DisplayName = user.Username
            };
            await HttpContext.SignInAsync(isuser);

            // Open-redirect protection: validate returnUrl before redirecting
            if (context != null || await _interaction.IsValidReturnUrl(ReturnUrl))
                return Redirect(ReturnUrl!);      // back to /connect/authorize
            if (Url.IsLocalUrl(ReturnUrl))
                return Redirect(ReturnUrl);
            return Redirect("~/");
        }

        ModelState.AddModelError(string.Empty, "Invalid username or password");
        return Page();
    }
}
```

## Login.cshtml
```html
@page
@model LoginModel
<h1>Login</h1>
@if (Model.ClientName != null)
{
    <p>Sign in to continue to <strong>@Model.ClientName</strong></p>
}
<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />
    <div asp-validation-summary="All"></div>
    <label asp-for="Username"></label><input asp-for="Username" />
    <label asp-for="Password"></label><input asp-for="Password" type="password" />
    <button type="submit">Login</button>
</form>
```

## Notes
- **Context**: `GetAuthorizationContextAsync(returnUrl)` returns the client, `IdP`, `LoginHint`, `Tenant`, etc.; `null` means the returnUrl isn't a valid authorize request.
- **Session**: `IdentityServerUser` with `SubjectId` (the required `sub`). `amr=pwd`, `idp=local`, `auth_time` default automatically.
- **Open redirect**: only redirect after `IsValidReturnUrl` / non-null context / `Url.IsLocalUrl`. 
- **returnUrl preservation**: the hidden field keeps it across the post-back (a common pitfall otherwise).
- Redirecting to `returnUrl` re-issues the authorize request so IdentityServer completes the protocol flow (consent is next for `web.app`, since `RequireConsent = true`).
