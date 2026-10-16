# Self-service registration with `prompt=create`

## Host configuration
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.CreateAccountUrl = "/Account/Register";
});
```
Setting `CreateAccountUrl` makes IdentityServer advertise `create` in `prompt_values_supported` (discovery). If unset, `prompt=create` is ignored and not advertised. Requests with `prompt=create` are redirected to `/Account/Register?returnUrl=...`. Note `create` must be the **only** prompt value (not combined with `login`, `consent`, `select_account`, `none`).

## ASP.NET Core client kicking off registration
```csharp
app.MapGet("/register", () => Results.Challenge(
    new OpenIdConnectChallengeProperties { Prompt = "create", RedirectUri = "/" },
    ["oidc"]));
```

## Registration page (host)
```csharp
public class RegisterModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly IUserService _users;       // your user store
    private readonly IEmailSender _email;

    [BindProperty] public InputModel Input { get; set; } = new();
    [BindProperty] public string? ReturnUrl { get; set; }

    public void OnGet(string? returnUrl) => ReturnUrl = returnUrl;

    public async Task<IActionResult> OnPost(CancellationToken ct)
    {
        // Returns null for an invalid returnUrl → prevents open redirects
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl, ct);
        if (context is null) return Redirect("~/");

        if (!ModelState.IsValid) return Page();

        var user = await _users.CreateAsync(Input.Email, Input.Password);   // unconfirmed
        var token = await _users.GenerateEmailConfirmationTokenAsync(user);
        var link = Url.Page("/Account/ConfirmEmail", null,
            new { userId = user.SubjectId, token, returnUrl = ReturnUrl }, Request.Scheme);
        await _email.SendAsync(user.Email, "Confirm your email", link!);

        // NOT signed in yet
        return RedirectToPage("RegisterConfirmation");
    }
}
```

ConfirmEmail handler – the only place the session is created:
```csharp
public async Task<IActionResult> OnGet(string userId, string token, string? returnUrl)
{
    var user = await _users.FindByIdAsync(userId);
    if (user is null || !await _users.ConfirmEmailAsync(user, token)) return BadRequest();

    // Sign in ONLY after email confirmation
    await HttpContext.SignInAsync(new IdentityServerUser(user.SubjectId) { DisplayName = user.Email });

    var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
    return context is null ? Redirect("~/") : Redirect(returnUrl!);   // resumes authorize request
}
```

## Key points
- `GetAuthorizationContextAsync` returning null signals a bad/forged `returnUrl` — redirect away.
- No `SignInAsync` on registration submit; only after confirmation (also applies to approval or MFA steps).
- The `returnUrl` is carried in the confirmation link and re-validated there.
