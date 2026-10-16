# Login page (Razor Pages)

**Program.cs** – configure the login URL:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.LoginUrl = "/Account/Login";
    options.UserInteraction.LoginReturnUrlParameter = "returnUrl";
})
```
Register the test user store: `builder.Services.AddSingleton<TestUserStore>(...)` is already provided by `.AddTestUsers(...)`, so just inject `TestUserStore`.

**Pages/Account/Login.cshtml.cs**

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Test;
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

    public async Task<IActionResult> OnGetAsync(string? returnUrl)
    {
        ReturnUrl = returnUrl;
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        ClientName = context?.Client?.ClientName ?? context?.Client?.ClientId;
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        ClientName = context?.Client?.ClientName;

        if (_users.ValidateCredentials(Username, Password))
        {
            var user = _users.FindByUsername(Username);
            var isuser = new IdentityServerUser(user.SubjectId)
            {
                DisplayName = user.Username
            };
            await HttpContext.SignInAsync(isuser);

            if (context != null)
                return Redirect(ReturnUrl!);          // validated by the interaction service

            if (Url.IsLocalUrl(ReturnUrl))
                return Redirect(ReturnUrl);
            if (string.IsNullOrEmpty(ReturnUrl))
                return Redirect("~/");
            throw new ArgumentException("invalid return URL");
        }

        ModelState.AddModelError("", "Invalid username or password");
        return Page();
    }
}
```

**Login.cshtml**

```html
@page
@model LoginModel
<h1>Login</h1>
@if (Model.ClientName != null) { <p>Sign in to <strong>@Model.ClientName</strong></p> }
<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />
    <div asp-validation-summary="All"></div>
    <input asp-for="Username" placeholder="Username" />
    <input asp-for="Password" type="password" />
    <button type="submit">Login</button>
</form>
```

## Open-redirect protection
The `returnUrl` must either be recognised by `GetAuthorizationContextAsync` (non-null context means IdentityServer created/validated it) or be a local URL (`Url.IsLocalUrl`). Anything else is rejected. Anti-forgery is automatically applied to Razor Pages forms.
