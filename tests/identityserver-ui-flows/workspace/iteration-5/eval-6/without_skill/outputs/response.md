# Home Realm Discovery on the Login Page

We need three behaviors: honor an IdP hint from the client, route corporate emails to Azure AD, and limit which providers a given client can use.

## 1. Restrict providers for spa.app

Configure the `spa.app` client so it can only use Google and local login (not AAD):

```csharp
new Client
{
    ClientId = "spa.app",
    // ... existing settings ...
    AllowedScopes = { "openid", "profile", "api1" },
    RequireConsent = false,
    IdentityProviderRestrictions = { "Google", "local" }
}
```

Because `AAD` is not in the list, IdentityServer will not treat it as an allowed provider for this client.

## 2. Register providers

```csharp
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Azure AD", o =>
    {
        o.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
    })
    .AddGoogle("Google", o =>
    {
        o.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
    });
```

## 3. Login page with HRD logic

```csharp
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

    [BindProperty] public string Email { get; set; }
    [BindProperty(SupportsGet = true)] public string ReturnUrl { get; set; }

    public async Task<IActionResult> OnGetAsync(string returnUrl)
    {
        ReturnUrl = returnUrl;
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

        // If the client passed an idp hint via acr_values (idp:AAD), skip the UI
        if (context != null && !string.IsNullOrEmpty(context.IdP))
        {
            var props = new AuthenticationProperties
            {
                RedirectUri = Url.Action("Callback"),
                Items = { { "returnUrl", returnUrl } }
            };
            return Challenge(props, context.IdP);
        }

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        // Route corporate users to Azure AD based on email domain
        if (!string.IsNullOrEmpty(Email) &&
            Email.EndsWith("@contoso.com", StringComparison.OrdinalIgnoreCase))
        {
            var props = new AuthenticationProperties
            {
                RedirectUri = Url.Action("Callback"),
                Items = { { "returnUrl", ReturnUrl } }
            };
            return Challenge(props, "AAD");
        }

        // Otherwise fall back to Google or local login
        return Page();
    }
}
```

## Summary

- The client can hint the provider through `acr_values=idp:AAD`; the login page reads `context.IdP` and issues a `Challenge` to that scheme without showing the form.
- On submit, `@contoso.com` addresses are challenged against `AAD`; everyone else uses Google or local.
- `spa.app` is locked to `Google` and `local` via `IdentityProviderRestrictions`, so `AAD` is never presented for that client.
