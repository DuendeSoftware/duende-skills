# Home Realm Discovery

## Client Configuration

```csharp
new Client
{
    ClientId = "spa.app",
    // ... existing config ...
    IdentityProviderRestrictions = { "Google", "local" }
}
```

## Login Page with HRD

```csharp
public class LoginModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public LoginModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    [BindProperty]
    public string Email { get; set; }
    [BindProperty]
    public string ReturnUrl { get; set; }

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

        // Check for IdP hint in acr_values
        if (context?.IdP != null)
        {
            var props = new AuthenticationProperties
            {
                RedirectUri = "/callback",
                Items = { { "returnUrl", returnUrl } }
            };
            return Challenge(props, context.IdP);
        }

        return Page();
    }

    public IActionResult OnPostRoute()
    {
        if (Email.EndsWith("@contoso.com"))
        {
            var props = new AuthenticationProperties
            {
                RedirectUri = "/callback",
                Items = { { "returnUrl", ReturnUrl } }
            };
            return Challenge(props, "AAD");
        }

        return Page(); // Show other options
    }
}
```

This implements HRD with acr_values hint detection and email-domain routing.
