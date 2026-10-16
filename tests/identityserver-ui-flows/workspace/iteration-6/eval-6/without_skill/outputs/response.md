# Home Realm Discovery

## Program.cs
```csharp
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", o => { o.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme; /* authority etc. */ })
    .AddGoogle("Google", o => { o.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme; /* id/secret */ });
```
Restrict spa.app:
```csharp
new Client { ClientId = "spa.app", /* ... */
    IdentityProviderRestrictions = { "Google" } }
```
(An empty list = all providers; a non-empty list = only those listed. Local login is controlled by `EnableLocalLogin = true`, which is the default, so local login stays available.)

## Login page
```csharp
public class LoginModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly IAuthenticationSchemeProvider _schemes;
    public LoginModel(IIdentityServerInteractionService i, IAuthenticationSchemeProvider s) { _interaction = i; _schemes = s; }

    [BindProperty] public string? ReturnUrl { get; set; }
    [BindProperty] public string? Email { get; set; }
    public List<string> Providers { get; set; } = new();
    public bool AllowLocal { get; set; } = true;

    public async Task<IActionResult> OnGetAsync(string? returnUrl)
    {
        ReturnUrl = returnUrl;
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

        // 1) idp hint
        if (context?.IdP != null)
        {
            var scheme = (await _schemes.GetAllSchemesAsync()).FirstOrDefault(s => s.Name == context.IdP);
            if (scheme != null)
                return RedirectToPage("/ExternalLogin/Challenge", new { scheme = context.IdP, returnUrl });
        }

        // Also honour acr_values "idp:AAD"
        var idpAcr = context?.AcrValues?.FirstOrDefault(a => a.StartsWith("idp:"));
        if (idpAcr != null)
            return RedirectToPage("/ExternalLogin/Challenge", new { scheme = idpAcr["idp:".Length..], returnUrl });

        // Build list honouring client restrictions
        var all = (await _schemes.GetAllSchemesAsync()).Where(s => s.DisplayName != null).Select(s => s.Name);
        var allowed = context?.Client?.IdentityProviderRestrictions;
        Providers = (allowed?.Any() == true ? all.Where(allowed.Contains) : all).ToList();
        return Page();
    }

    public async Task<IActionResult> OnPostEmailAsync()
    {
        // 2) email-based routing
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (Email != null && Email.EndsWith("@contoso.com", StringComparison.OrdinalIgnoreCase))
        {
            var restrictions = context?.Client?.IdentityProviderRestrictions;
            if (restrictions == null || !restrictions.Any() || restrictions.Contains("AAD"))
                return RedirectToPage("/ExternalLogin/Challenge", new { scheme = "AAD", returnUrl = ReturnUrl });
        }
        // otherwise show the local password form / Google
        return Page();
    }
}
```
Note: IdentityServer itself interprets `acr_values=idp:AAD` and exposes it as `context.IdP`; the tenant hint `tenant:` is exposed as `context.Tenant`. The IdentityProviderRestrictions are NOT enforced automatically by the UI - the login page must filter on them (and IdentityServer rejects tokens from restricted providers only if the page does it).
