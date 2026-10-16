# Self-service registration with prompt=create

## IdentityServer host
```csharp
builder.Services.AddIdentityServer(options =>
{
    options.UserInteraction.CreateAccountUrl = "/Account/Register";
    options.UserInteraction.LoginUrl = "/Account/Login";
});
```
Setting `CreateAccountUrl` makes discovery advertise `create` in `prompt_values_supported`. IdentityServer then redirects `prompt=create` requests to that URL with `returnUrl`.

## ASP.NET Core client
```csharp
.AddOpenIdConnect("oidc", options =>
{
    options.Events.OnRedirectToIdentityProvider = ctx =>
    {
        if (ctx.Properties.Items.TryGetValue("prompt", out var p) && p == "create")
            ctx.ProtocolMessage.Prompt = "create";
        return Task.CompletedTask;
    };
});

// endpoint
app.MapGet("/register", () => Results.Challenge(
    new AuthenticationProperties { RedirectUri = "/", Items = { ["prompt"] = "create" } },
    new[] { "oidc" }));
```

## Register page
```csharp
public class RegisterModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly UserManager<AppUser> _users;
    private readonly IEmailSender _email;
    ...
    [BindProperty] public InputModel Input { get; set; } = new();
    [BindProperty] public string? ReturnUrl { get; set; }

    public void OnGet(string? returnUrl) => ReturnUrl = returnUrl;

    public async Task<IActionResult> OnPostAsync()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (context == null && !Url.IsLocalUrl(ReturnUrl)) return BadRequest("invalid returnUrl");
        if (!ModelState.IsValid) return Page();

        var user = new AppUser { UserName = Input.Email, Email = Input.Email };
        var result = await _users.CreateAsync(user, Input.Password);
        if (!result.Succeeded) { foreach (var e in result.Errors) ModelState.AddModelError("", e.Description); return Page(); }

        var token = await _users.GenerateEmailConfirmationTokenAsync(user);
        var link = Url.Page("/Account/ConfirmEmail", null, new { userId = user.Id, token, returnUrl = ReturnUrl }, Request.Scheme);
        await _email.SendAsync(user.Email, "Confirm your email", link);
        return RedirectToPage("RegisterConfirmation");
    }
}
```
ConfirmEmail page:
```csharp
var user = await _users.FindByIdAsync(userId);
var r = await _users.ConfirmEmailAsync(user, token);
if (r.Succeeded)
{
    await HttpContext.SignInAsync(new IdentityServerUser(user.Id) { DisplayName = user.UserName });
    var ctx = await _interaction.GetAuthorizationContextAsync(returnUrl);
    if (ctx != null || Url.IsLocalUrl(returnUrl)) return Redirect(returnUrl);
    return Redirect("~/");
}
```
The user is not signed in at registration time; sign-in occurs only after the confirmation link is clicked.
