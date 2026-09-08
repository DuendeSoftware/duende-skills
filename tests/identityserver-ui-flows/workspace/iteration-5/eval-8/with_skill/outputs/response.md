# Self-Service Registration via prompt=create

`prompt=create` is a standardized OIDC parameter that tells the authorization server to send the user straight to a **registration** page rather than login. It has three moving parts: host discovery configuration, the client trigger, and the registration page handler.

## 1. Host configuration — advertise `create` in discovery

Set `CreateAccountUrl` in `AddIdentityServer`. This does two things: it routes `prompt=create` requests to `/Account/Register`, **and** it makes IdentityServer advertise `create` in `prompt_values_supported` in the discovery document (`/.well-known/openid-configuration`).

```csharp
// Program.cs (host)
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.CreateAccountUrl = "/Account/Register";
});
```

> **Important:** If `CreateAccountUrl` is left unset, IdentityServer does **not** advertise `create` in discovery and **ignores** any incoming `prompt=create` — the parameter is silently dropped. Also, `prompt=create` must be the *only* prompt value; it cannot be combined with `login`, `consent`, `select_account`, or `none`.

## 2. Client — kick off registration

From an ASP.NET Core OIDC client, start the flow with a challenge that sets `Prompt = "create"`:

```csharp
// Client app (e.g. a minimal API endpoint or Razor handler)
app.MapGet("/register", () =>
    Results.Challenge(
        new OpenIdConnectChallengeProperties
        {
            Prompt = "create",
            RedirectUri = "/"
        },
        authenticationSchemes: ["oidc"]));
```

This produces an `/connect/authorize?...&prompt=create` request; IdentityServer sees the `create` prompt and redirects to `/Account/Register`.

## 3. Registration page handler (host)

Resolve the authorization context safely, create the user, and — critically — sign the user in **only after email confirmation**, then redirect back to `returnUrl`.

```csharp
// Pages/Account/Register.cshtml.cs (host)
public class RegisterModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly IUserStore _users;

    public RegisterModel(IIdentityServerInteractionService interaction, IUserStore users)
    {
        _interaction = interaction;
        _users = users;
    }

    [BindProperty] public string Email { get; set; } = default!;
    [BindProperty] public string Password { get; set; } = default!;
    [BindProperty(SupportsGet = true)] public string? ReturnUrl { get; set; }

    public async Task<IActionResult> OnPost(string? returnUrl, CancellationToken ct)
    {
        // GetAuthorizationContextAsync returns null for an invalid/foreign returnUrl.
        // Redirect away rather than trusting it → prevents open redirect.
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl, ct);
        if (context is null)
        {
            return Redirect("~/");
        }

        // Create + persist the local user (unconfirmed at this point)
        var user = await _users.CreateAsync(Email, Password, ct);

        // Send confirmation email; do NOT sign in yet
        await _users.SendEmailConfirmationAsync(user, ct);

        // Land on a "check your email" page — session established later
        return RedirectToPage("/Account/RegisterConfirmation", new { returnUrl });
    }
}
```

### Establishing the session only after email confirmation

The sign-in happens in the email-confirmation callback, not on form submit:

```csharp
// Pages/Account/ConfirmEmail.cshtml.cs (host)
public async Task<IActionResult> OnGet(string userId, string token, string? returnUrl, CancellationToken ct)
{
    var user = await _users.ConfirmEmailAsync(userId, token, ct);
    if (user is null) return Redirect("~/");

    // Re-validate the returnUrl before trusting it
    var context = await _interaction.GetAuthorizationContextAsync(returnUrl, ct);
    if (context is null) return Redirect("~/");

    // NOW establish the session — only after confirmation
    await HttpContext.SignInAsync(new IdentityServerUser(user.SubjectId)
    {
        DisplayName = user.Email
    });

    return Redirect(returnUrl!);
}
```

## Flow summary

| Step | Where | Call |
| ---- | ----- | ---- |
| Advertise + route `create` | Host `Program.cs` | `options.UserInteraction.CreateAccountUrl = "/Account/Register"` |
| Trigger registration | Client | `Results.Challenge(new OpenIdConnectChallengeProperties { Prompt = "create" }, ["oidc"])` |
| Resolve context safely | Host register handler | `GetAuthorizationContextAsync(returnUrl)`; redirect away if `null` |
| Create user | Host | persist unconfirmed user, send confirmation email |
| Sign in | Host confirm-email handler | `HttpContext.SignInAsync(new IdentityServerUser(subjectId))` **after** confirmation, then `Redirect(returnUrl)` |

**Key correctness points**
- `CreateAccountUrl` unset ⇒ `create` is neither advertised nor honored.
- A `null` result from `GetAuthorizationContextAsync` signals an invalid `returnUrl` — never redirect to it.
- The user is signed in **only after** email confirmation, satisfying the requirement that registration doesn't grant a session on submit.
