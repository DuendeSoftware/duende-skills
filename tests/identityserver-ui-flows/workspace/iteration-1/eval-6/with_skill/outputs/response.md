# Home Realm Discovery (HRD) Implementation

Here's a complete HRD implementation for your login page with three providers.

## Program.cs — Configure Client Restrictions

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

builder.Services.AddIdentityServer()
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web.app",
            ClientName = "Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://app.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "email", "api1" },
            RequireConsent = true
        },
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
            // Restrict spa.app to only Google and local login — exclude AAD
            IdentityProviderRestrictions = { "Google", "local" }
        }
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "My API")
    })
    .AddTestUsers(new List<Duende.IdentityServer.Test.TestUser>());

// Register external providers
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://login.microsoftonline.com/contoso.com/v2.0";
        options.ClientId = "aad-client-id";
        options.ResponseType = "code";
    })
    .AddGoogle("Google", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.ClientId = "google-client-id";
        options.ClientSecret = "google-secret";
    });

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Pages/Login.cshtml.cs — HRD Logic

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Test;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages;

public class LoginModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly TestUserStore _users;

    public LoginModel(
        IIdentityServerInteractionService interaction,
        TestUserStore users)
    {
        _interaction = interaction;
        _users = users;
    }

    [BindProperty]
    public string Email { get; set; }

    [BindProperty]
    public string Password { get; set; }

    [BindProperty]
    public string ReturnUrl { get; set; }

    public List<string> AvailableProviders { get; set; } = new();
    public bool ShowLoginForm { get; set; } = true;

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;

        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

        // Step 1: Check if context has an IdP hint via acr_values
        // If context.IdP is set, skip the login UI and redirect directly to that provider
        if (context?.IdP != null && context.IdP != Duende.IdentityServer.IdentityServerConstants.LocalIdentityProvider)
        {
            // IdP hint present — bypass login UI, issue Challenge directly
            return ChallengeExternalProvider(context.IdP, returnUrl);
        }

        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);

        // Step 2: Email-domain-based routing
        if (!string.IsNullOrEmpty(Email) && string.IsNullOrEmpty(Password))
        {
            // Check domain for HRD
            if (Email.EndsWith("@contoso.com", StringComparison.OrdinalIgnoreCase))
            {
                // Route @contoso.com users to AAD
                return ChallengeExternalProvider("AAD", ReturnUrl);
            }

            // Non-contoso domain: show password field and available providers
            ShowLoginForm = true;
            return Page();
        }

        // Step 3: Local login with credentials
        if (_users.ValidateCredentials(Email, Password))
        {
            var user = _users.FindByUsername(Email);
            var isUser = new IdentityServerUser(user.SubjectId)
            {
                DisplayName = user.Username
            };
            await HttpContext.SignInAsync(isUser);

            if (_interaction.IsValidReturnUrl(ReturnUrl) || Url.IsLocalUrl(ReturnUrl))
            {
                return Redirect(ReturnUrl);
            }
            return Redirect("~/");
        }

        ModelState.AddModelError(string.Empty, "Invalid credentials");
        return Page();
    }

    private IActionResult ChallengeExternalProvider(string provider, string returnUrl)
    {
        var callbackUrl = Url.Page("/ExternalLoginCallback");
        var props = new AuthenticationProperties
        {
            RedirectUri = callbackUrl,
            Items =
            {
                { "scheme", provider },
                { "returnUrl", returnUrl }
            }
        };

        // Issue Challenge to the determined external provider
        return Challenge(props, provider);
    }
}
```

### Key Points

1. **IdP hint check**: The login page checks `context.IdP` from `GetAuthorizationContextAsync`. If an IdP hint is present (via `acr_values=idp:AAD`), the login UI is bypassed entirely and a `Challenge` is issued directly to that provider.
2. **Email-domain routing**: `@contoso.com` addresses are routed to the `AAD` provider via `Challenge`.
3. **IdentityProviderRestrictions**: The `spa.app` client has `IdentityProviderRestrictions = { "Google", "local" }` — this includes Google and local login but excludes AAD.
4. **Challenge**: `ChallengeExternalProvider` issues a `Challenge` to the appropriate external provider scheme.
