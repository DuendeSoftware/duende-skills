# Home Realm Discovery (HRD) on the Login Page

HRD decides *which* identity provider authenticates the user. We combine three strategies:

1. **`acr_values` IdP hint** — if the client passed `idp:<scheme>`, skip the UI and challenge that provider directly.
2. **Email-domain routing** — `@contoso.com` → `AAD`, everything else → Google/local choice.
3. **`IdentityProviderRestrictions`** — restrict `spa.app` to `Google` + `local` so `AAD` is never offered.

## 1. Restrict providers on spa.app (Program.cs)

```csharp
new Client
{
    ClientId = "spa.app",
    ClientName = "SPA Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RequireClientSecret = false,
    RedirectUris = { "https://spa.example.com/callback" },
    PostLogoutRedirectUris = { "https://spa.example.com" },
    AllowedScopes = { "openid", "profile", "api1" },
    RequireConsent = false,

    // Only Google and local login are available for this client; AAD is excluded
    IdentityProviderRestrictions = { "Google", "local" }
}
```

## 2. Register the external providers (Program.cs)

```csharp
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Azure AD", o =>
    {
        o.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        // authority, client id, etc.
    })
    .AddGoogle("Google", o =>
    {
        o.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        // client id/secret
    });
```

## 3. Login page with HRD (Pages/Account/Login.cshtml.cs)

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages.Account;

public class LoginModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public LoginModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    [BindProperty] public string? Email { get; set; }
    [BindProperty(SupportsGet = true)] public string? ReturnUrl { get; set; }

    // Providers to render, honoring IdentityProviderRestrictions
    public List<string> VisibleProviders { get; set; } = new();
    public bool AllowLocal { get; set; } = true;

    public async Task<IActionResult> OnGet(string? returnUrl)
    {
        ReturnUrl = returnUrl;
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

        // STRATEGY 1: acr_values idp hint → bypass the UI entirely
        if (!string.IsNullOrEmpty(context?.IdP))
        {
            // The client already told us which provider to use
            return Challenge(context.IdP, BuildProps(returnUrl));
        }

        // STRATEGY 3: respect IdentityProviderRestrictions for this client
        var restrictions = context?.Client?.IdentityProviderRestrictions;
        var all = new[] { "AAD", "Google" };
        VisibleProviders = (restrictions is { Count: > 0 })
            ? all.Where(p => restrictions.Contains(p)).ToList()
            : all.ToList();
        AllowLocal = restrictions is not { Count: > 0 } || restrictions.Contains("local");

        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        // STRATEGY 2: email-domain routing
        if (!string.IsNullOrEmpty(Email) &&
            Email.EndsWith("@contoso.com", StringComparison.OrdinalIgnoreCase))
        {
            return Challenge("AAD", BuildProps(ReturnUrl));
        }

        // Fall through to local login / other providers (validate credentials, etc.)
        return Page();
    }

    private AuthenticationProperties BuildProps(string? returnUrl) => new()
    {
        RedirectUri = Url.Page("/Account/ExternalLogin", "Callback"),
        Items =
        {
            { "returnUrl", returnUrl },
        }
    };
}
```

## How the three strategies fit together

| Strategy | Where | Effect |
| -------- | ----- | ------ |
| `acr_values` hint (`idp:AAD`) | `OnGet` reads `context.IdP` | Immediately `Challenge(context.IdP)` — no login UI shown |
| Email-domain routing | `OnPost` inspects the entered email | `@contoso.com` → `Challenge("AAD")`; others → Google/local |
| `IdentityProviderRestrictions` | `spa.app` client config + `OnGet` filtering | Only `Google` + `local` rendered; `AAD` hidden for that client |

**Key points**
- Read `context.IdP` from `GetAuthorizationContextAsync` — never parse `returnUrl`. When it's set, skip the UI and challenge that scheme directly.
- Filter the provider buttons against `context.Client.IdentityProviderRestrictions` so a restricted client (`spa.app`) never sees `AAD`.
- For a fuller solution, enumerate static schemes via `IAuthenticationSchemeProvider` and dynamic ones via `IIdentityProviderStore`, then intersect with the restrictions.
