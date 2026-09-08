# Self-Service Registration with prompt=create

`prompt=create` is the OpenID Connect parameter (from the "Initiating User Registration via OpenID Connect" spec) that asks the provider to show a registration screen instead of a login screen. Here's how to wire it up.

## 1. Route prompt=create to a registration page (host)

IdentityServer sends interactive requests to the login page. To handle `prompt=create`, inspect the incoming authorize request and, when the prompt is `create`, send the user to your registration page instead of the login form.

A straightforward approach is to check the prompt in your login page and redirect:

```csharp
public async Task<IActionResult> OnGetAsync(string returnUrl)
{
    var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

    // If the client asked to register, go to the registration page
    var prompt = context?.Parameters?["prompt"];
    if (prompt == "create")
    {
        return RedirectToPage("/Account/Register", new { returnUrl });
    }

    return Page();
}
```

> Note: you'll want IdentityServer to advertise support for the `create` prompt so clients know it's available. Make sure your discovery document lists it, and that the host actually acts on the parameter as shown above — otherwise clients sending `prompt=create` will just get the normal login page.

## 2. Trigger registration from the client

From an ASP.NET Core OIDC client, challenge with the `create` prompt:

```csharp
app.MapGet("/register", () =>
    Results.Challenge(
        new OpenIdConnectChallengeProperties
        {
            Prompt = "create",
            RedirectUri = "/"
        },
        new[] { "oidc" }));
```

## 3. Registration page handler (host)

Resolve the authorization context, create the user, and only sign them in after their email is confirmed.

```csharp
public class RegisterModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly IUserService _users;

    public RegisterModel(IIdentityServerInteractionService interaction, IUserService users)
    {
        _interaction = interaction;
        _users = users;
    }

    [BindProperty] public string Email { get; set; }
    [BindProperty] public string Password { get; set; }
    [BindProperty(SupportsGet = true)] public string ReturnUrl { get; set; }

    public async Task<IActionResult> OnPostAsync(string returnUrl)
    {
        // Safely resolve the authorization context; null means an invalid returnUrl
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context == null)
        {
            return Redirect("~/");
        }

        // Create the (unconfirmed) user and send a confirmation email
        var user = await _users.CreateAsync(Email, Password);
        await _users.SendConfirmationEmailAsync(user);

        // Do NOT sign in yet — wait for email confirmation
        return RedirectToPage("/Account/CheckYourEmail");
    }
}

public class ConfirmEmailModel : PageModel
{
    // ... injected _interaction, _users ...

    public async Task<IActionResult> OnGetAsync(string userId, string token, string returnUrl)
    {
        var user = await _users.ConfirmEmailAsync(userId, token);
        if (user == null) return Redirect("~/");

        // Now that the email is confirmed, establish the session
        await HttpContext.SignInAsync(new IdentityServerUser(user.SubjectId));

        return Redirect(returnUrl);
    }
}
```

## Summary

- `prompt=create` should route the user to registration rather than login.
- The client uses `OpenIdConnectChallengeProperties { Prompt = "create" }` to start the flow.
- The registration handler resolves the context with `GetAuthorizationContextAsync` and redirects away if it's `null` (open-redirect protection).
- The user is signed in with `HttpContext.SignInAsync(new IdentityServerUser(...))` only after confirming their email, then redirected back to `returnUrl`.
