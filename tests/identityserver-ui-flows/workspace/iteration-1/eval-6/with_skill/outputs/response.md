# Home Realm Discovery Implementation

## 1. Update spa.app Client with IdentityProviderRestrictions

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
    IdentityProviderRestrictions = { "Google", "local" }  // Only Google and local login
}
```

## 2. Login Page with HRD Logic

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class LoginModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public LoginModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    [BindProperty]
    public string Email { get; set; } = string.Empty;
    [BindProperty]
    public string ReturnUrl { get; set; } = string.Empty;

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

        if (context != null)
        {
            // Check if there's an IdP hint from acr_values (e.g., idp:AAD)
            if (!string.IsNullOrEmpty(context.IdP))
            {
                // Skip the login UI — redirect directly to the hinted provider
                return ChallengeExternalProvider(context.IdP, returnUrl);
            }
        }

        return Page();
    }

    public async Task<IActionResult> OnPostEmailDiscovery()
    {
        if (string.IsNullOrEmpty(Email))
        {
            ModelState.AddModelError("", "Email is required");
            return Page();
        }

        // Email-domain-based HRD routing
        if (Email.EndsWith("@contoso.com", StringComparison.OrdinalIgnoreCase))
        {
            // Route @contoso.com users to AAD
            return ChallengeExternalProvider("AAD", ReturnUrl);
        }

        // For all other users, show Google and local login options
        return Page();
    }

    private IActionResult ChallengeExternalProvider(string scheme, string returnUrl)
    {
        var callbackUrl = Url.Page("/ExternalLoginCallback");
        var props = new AuthenticationProperties
        {
            RedirectUri = callbackUrl,
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

## Key Design Points

1. **IdP Hint via acr_values**: The login page checks `context.IdP` from `GetAuthorizationContextAsync`. If a provider hint is present, the login UI is bypassed entirely — the user is immediately redirected to that external provider via `Challenge`.

2. **Email-Domain-Based Routing**: When no IdP hint is present, the page collects the user's email. `@contoso.com` addresses are routed to the AAD provider.

3. **IdentityProviderRestrictions**: The `spa.app` client has `IdentityProviderRestrictions = { "Google", "local" }`, which means only Google and local login are available for that client. AAD is excluded.

4. **Challenge**: The `ChallengeExternalProvider` method issues a `Challenge` to the appropriate external provider scheme.
