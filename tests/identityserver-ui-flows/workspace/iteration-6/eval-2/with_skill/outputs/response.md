# Azure AD as external IdP ("AAD" / "Corporate Login")

## Program.cs
```csharp
builder.Services.AddIdentityServer(/* ... */);

builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.SignOutScheme = IdentityServerConstants.SignoutScheme; // IdentityConstants.ApplicationScheme if using ASP.NET Identity
        options.Authority = "https://login.microsoftonline.com/<tenant-id>/v2.0";
        options.ClientId = builder.Configuration["AAD:ClientId"];
        options.ClientSecret = builder.Configuration["AAD:ClientSecret"];
        options.ResponseType = "code";
        options.CallbackPath = "/signin-aad";
        options.Scope.Add("email");
    });

// Optional: avoid long state in the URL
builder.Services.AddOidcStateDataFormatterCache("AAD");
```

## Challenge (Pages/ExternalLogin/Challenge.cshtml.cs)
```csharp
public class ChallengeModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    public ChallengeModel(IIdentityServerInteractionService interaction) => _interaction = interaction;

    public async Task<IActionResult> OnGet(string scheme, string? returnUrl)
    {
        if (string.IsNullOrEmpty(returnUrl)) returnUrl = "~/";

        // prevent open redirects
        if (!Url.IsLocalUrl(returnUrl) && !await _interaction.IsValidReturnUrl(returnUrl))
            throw new ArgumentException("invalid return URL");

        var props = new AuthenticationProperties
        {
            RedirectUri = Url.Page("/ExternalLogin/Callback"),
            Items =
            {
                { "scheme", scheme },
                { "returnUrl", returnUrl }
            }
        };
        return Challenge(props, scheme);
    }
}
```
Login page links: `/ExternalLogin/Challenge?scheme=AAD&returnUrl=@Model.ReturnUrl`.

## Callback (Pages/ExternalLogin/Callback.cshtml.cs)
```csharp
public class CallbackModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly TestUserStore _users;
    public CallbackModel(IIdentityServerInteractionService interaction, TestUserStore users)
    { _interaction = interaction; _users = users; }

    public async Task<IActionResult> OnGet()
    {
        // 1. Read the external identity from the temporary cookie
        var result = await HttpContext.AuthenticateAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);
        if (result?.Succeeded != true) throw new InvalidOperationException("External authentication error");

        var external = result.Principal!;
        var userIdClaim = external.FindFirst(JwtClaimTypes.Subject)
                       ?? external.FindFirst(ClaimTypes.NameIdentifier)
                       ?? throw new InvalidOperationException("Unknown userid");
        var scheme = result.Properties!.Items["scheme"]!;
        var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";

        // 2. Find or provision a local user (external sub is provider-specific; map it, don't reuse it)
        var user = _users.FindByExternalProvider(scheme, userIdClaim.Value)
                   ?? _users.AutoProvisionUser(scheme, userIdClaim.Value, external.Claims.ToList());

        // 3. Establish the IdentityServer session, recording the external IdP
        await HttpContext.SignInAsync(new IdentityServerUser(user.SubjectId)
        {
            DisplayName = user.Username,
            IdentityProvider = scheme            // "AAD"
        });

        // 4. Clean up the external cookie
        await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

        // 5. Back to protocol processing (validated)
        if (await _interaction.IsValidReturnUrl(returnUrl) || Url.IsLocalUrl(returnUrl))
            return Redirect(returnUrl);
        return Redirect("~/");
    }
}
```

## Key points
- `SignInScheme = ExternalCookieAuthenticationScheme` makes the handler write the external identity to a temporary cookie.
- `returnUrl` and the scheme travel in `AuthenticationProperties.Items`; `RedirectUri` is the callback page.
- `IdentityProvider = scheme` sets the `idp` claim (instead of default `local`), so logout can sign out of the external provider too.
- Always delete the external cookie after provisioning.
