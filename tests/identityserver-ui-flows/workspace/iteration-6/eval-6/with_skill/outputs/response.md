# Home Realm Discovery

## Program.cs
```csharp
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", o =>
    {
        o.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        // authority, client id/secret...
    })
    .AddGoogle("Google", o =>
    {
        o.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        // client id/secret...
    });
```

Restrict `spa.app` to Google + local:
```csharp
new Client
{
    ClientId = "spa.app",
    // ...
    IdentityProviderRestrictions = { "Google", IdentityServerConstants.LocalIdentityProvider } // "local"
}
```
If the client has restrictions and the hint isn't allowed, IdentityServer drops it (`context.IdP` becomes null, no error). The login page must also filter the UI list and the email-routing based on those restrictions.

## Login page
```csharp
public class LoginModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly IAuthenticationSchemeProvider _schemes;
    public LoginModel(IIdentityServerInteractionService i, IAuthenticationSchemeProvider s) { _interaction = i; _schemes = s; }

    [BindProperty] public string? ReturnUrl { get; set; }
    [BindProperty] public string? Email { get; set; }
    public bool ShowLocal { get; set; } = true;
    public List<string> Providers { get; set; } = new();

    public async Task<IActionResult> OnGet(string? returnUrl)
    {
        ReturnUrl = returnUrl;
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

        // 1) acr_values=idp:XYZ  -> context.IdP
        if (context?.IdP is { } idp)
        {
            if (idp == IdentityServerConstants.LocalIdentityProvider)
                return Page();                       // reserved: local form only

            // IdentityServer does NOT verify the scheme exists – we must
            if (await _schemes.GetSchemeAsync(idp) != null)
                return RedirectToPage("/ExternalLogin/Challenge", new { scheme = idp, returnUrl });
        }

        // No hint: build the allowed list (honouring IdentityProviderRestrictions)
        var restrictions = context?.Client.IdentityProviderRestrictions;
        bool Allowed(string name) => restrictions is null || restrictions.Count == 0 || restrictions.Contains(name);

        Providers = new[] { "AAD", "Google" }.Where(Allowed).ToList();
        ShowLocal = Allowed(IdentityServerConstants.LocalIdentityProvider);
        return Page();
    }

    // 2) Email-based routing
    public async Task<IActionResult> OnPostLookup()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (context is null && !Url.IsLocalUrl(ReturnUrl)) return Redirect("~/");

        var restrictions = context?.Client.IdentityProviderRestrictions;
        bool Allowed(string n) => restrictions is null || restrictions.Count == 0 || restrictions.Contains(n);

        if (Email?.EndsWith("@contoso.com", StringComparison.OrdinalIgnoreCase) == true && Allowed("AAD"))
            return RedirectToPage("/ExternalLogin/Challenge", new { scheme = "AAD", returnUrl = ReturnUrl });

        // everyone else: Google (consumer) or local password
        return Page();
    }
}
```
The Challenge page and Callback are the standard ones (store `scheme` and `returnUrl` in `AuthenticationProperties.Items`, set `IdentityProvider = scheme` on sign-in, delete the external cookie).

## Client-side hint
```csharp
options.Events.OnRedirectToIdentityProvider = ctx =>
{
    ctx.ProtocolMessage.AcrValues = "idp:Google";
    return Task.CompletedTask;
};
```
Behaviours worth knowing: `acr_values` is space separated, so hints can combine (`idp:Google tenant:acme`); if the existing session came from a different idp the login page is shown again; `idp:local` is reserved to mean local login only. For robustness, also enumerate dynamic providers via `IIdentityProviderStore`, not only static schemes.
