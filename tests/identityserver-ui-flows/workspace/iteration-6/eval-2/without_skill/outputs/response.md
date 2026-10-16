# Azure AD as external IdP

## Program.cs

```csharp
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.SignOutScheme = IdentityServerConstants.SignoutScheme;
        options.Authority = "https://login.microsoftonline.com/<tenant-id>/v2.0";
        options.ClientId = builder.Configuration["AAD:ClientId"];
        options.ClientSecret = builder.Configuration["AAD:ClientSecret"];
        options.ResponseType = "code";
        options.CallbackPath = "/signin-aad";
        options.Scope.Add("email");
        options.SaveTokens = false;
    });
```

## Challenge (Pages/ExternalLogin/Challenge.cshtml.cs)

```csharp
public class Challenge : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    public Challenge(IIdentityServerInteractionService i) => _interaction = i;

    public IActionResult OnGet(string scheme, string? returnUrl)
    {
        if (string.IsNullOrEmpty(returnUrl)) returnUrl = "~/";
        if (!Url.IsLocalUrl(returnUrl) && !_interaction.IsValidReturnUrl(returnUrl))
            throw new ArgumentException("invalid return URL");

        var props = new AuthenticationProperties
        {
            RedirectUri = Url.Page("/ExternalLogin/Callback"),
            Items = { { "scheme", scheme }, { "returnUrl", returnUrl } }
        };
        return Challenge(props, scheme);
    }
}
```
Link: `/ExternalLogin/Challenge?scheme=AAD&returnUrl=...`

## Callback

```csharp
public class Callback : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly TestUserStore _users;
    public Callback(IIdentityServerInteractionService i, TestUserStore u) { _interaction = i; _users = u; }

    public async Task<IActionResult> OnGet()
    {
        var result = await HttpContext.AuthenticateAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);
        if (result?.Succeeded != true) throw new InvalidOperationException("External authentication error");

        var external = result.Principal!;
        var userIdClaim = external.FindFirst(JwtClaimTypes.Subject) ?? external.FindFirst(ClaimTypes.NameIdentifier)
            ?? throw new InvalidOperationException("Unknown userid");
        var provider = result.Properties!.Items["scheme"]!;
        var providerUserId = userIdClaim.Value;

        var user = _users.FindByExternalProvider(provider, providerUserId)
                   ?? _users.AutoProvisionUser(provider, providerUserId, external.Claims.ToList());

        var additional = new List<Claim>();
        var sid = external.FindFirst(JwtClaimTypes.SessionId);
        if (sid != null) additional.Add(new Claim(JwtClaimTypes.SessionId, sid.Value));

        var props = new AuthenticationProperties();
        var idToken = result.Properties.GetTokenValue("id_token");
        if (idToken != null) props.StoreTokens(new[] { new AuthenticationToken { Name = "id_token", Value = idToken } });

        var isuser = new IdentityServerUser(user.SubjectId)
        {
            DisplayName = user.Username,
            IdentityProvider = provider,
            AdditionalClaims = additional
        };
        await HttpContext.SignInAsync(isuser, props);
        await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

        var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";
        return Redirect(returnUrl);
    }
}
```

Key points: `IdentityProvider = "AAD"` records the external IdP on the session; the external cookie is deleted after sign-in; the returnUrl travels in `AuthenticationProperties.Items`; it's validated at the challenge.
