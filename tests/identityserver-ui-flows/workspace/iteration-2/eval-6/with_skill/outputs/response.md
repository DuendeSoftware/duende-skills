# Home Realm Discovery (HRD) Implementation

Here's a login page with HRD support: IdP hint detection via `acr_values`, email-domain-based routing, and per-client `IdentityProviderRestrictions`.

## Updated Program.cs (spa.app client with IdentityProviderRestrictions)

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

builder.Services.AddIdentityServer(options =>
    {
        // TODO: Configure user interaction options
    })
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

            // Restrict spa.app to only Google and local login (no AAD)
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
    .AddTestUsers(new List<Duende.IdentityServer.Test.TestUser>
    {
        new Duende.IdentityServer.Test.TestUser
        {
            SubjectId = "1",
            Username = "alice",
            Password = "password"
        }
    });

// Register external providers
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Azure AD", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://login.microsoftonline.com/{tenant}/v2.0";
        options.ClientId = "your-aad-client-id";
        options.ResponseType = "code";
    })
    .AddOpenIdConnect("Google", "Google", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://accounts.google.com";
        options.ClientId = "your-google-client-id";
        options.ResponseType = "code";
    });

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Pages/Login.cshtml.cs — Login Page with HRD

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Test;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class LoginModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    private readonly TestUserStore _userStore;

    public LoginModel(
        IIdentityServerInteractionService interaction,
        TestUserStore userStore)
    {
        _interaction = interaction;
        _userStore = userStore;
    }

    [BindProperty]
    public string ReturnUrl { get; set; }

    [BindProperty]
    public string Email { get; set; }

    [BindProperty]
    public string Username { get; set; }

    [BindProperty]
    public string Password { get; set; }

    public bool ShowLocalLogin { get; set; } = true;
    public List<ExternalProvider> ExternalProviders { get; set; } = new();

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;

        // Get the authorization context to check for IdP hints
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

        // Strategy 1: Check for IdP hint via acr_values (context.IdP)
        // If an IdP hint is present, bypass the login UI entirely
        if (context?.IdP != null && context.IdP != Duende.IdentityServer.IdentityServerConstants.LocalIdentityProvider)
        {
            // Client sent acr_values=idp:AAD — skip login UI, go straight to the provider
            return ChallengeExternalProvider(context.IdP, returnUrl);
        }

        // Build list of available external providers, respecting client restrictions
        BuildProviderList(context);

        return Page();
    }

    public async Task<IActionResult> OnPostEmailCheck()
    {
        // Strategy 2: Email-domain-based routing
        if (!string.IsNullOrEmpty(Email) && Email.EndsWith("@contoso.com", StringComparison.OrdinalIgnoreCase))
        {
            // @contoso.com users are routed to AAD
            return ChallengeExternalProvider("AAD", ReturnUrl);
        }

        // Non-contoso users: show Google + local login options
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        BuildProviderList(context);

        return Page();
    }

    public async Task<IActionResult> OnPostLocalLogin()
    {
        if (_userStore.ValidateCredentials(Username, Password))
        {
            var user = _userStore.FindByUsername(Username);
            var isUser = new IdentityServerUser(user.SubjectId)
            {
                DisplayName = user.Username
            };
            await HttpContext.SignInAsync(isUser);

            if (await _interaction.IsValidReturnUrl(ReturnUrl))
            {
                return Redirect(ReturnUrl);
            }
            return Redirect("~/");
        }

        ModelState.AddModelError("", "Invalid credentials");
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

    private void BuildProviderList(Duende.IdentityServer.Models.AuthorizationRequest context)
    {
        // Check client's IdentityProviderRestrictions
        var restrictions = context?.Client?.IdentityProviderRestrictions;

        var providers = new List<ExternalProvider>();

        // AAD provider
        if (restrictions == null || !restrictions.Any() || restrictions.Contains("AAD"))
        {
            providers.Add(new ExternalProvider { Scheme = "AAD", DisplayName = "Azure AD" });
        }

        // Google provider
        if (restrictions == null || !restrictions.Any() || restrictions.Contains("Google"))
        {
            providers.Add(new ExternalProvider { Scheme = "Google", DisplayName = "Google" });
        }

        ExternalProviders = providers;

        // Show local login if restrictions allow it
        ShowLocalLogin = restrictions == null || !restrictions.Any() || restrictions.Contains("local");
    }
}

public class ExternalProvider
{
    public string Scheme { get; set; }
    public string DisplayName { get; set; }
}
```

## Key Points

1. **IdP hint detection**: The login page checks `context.IdP` from `GetAuthorizationContextAsync`. If an IdP hint is present (from `acr_values=idp:AAD`), the login UI is bypassed entirely and the user is redirected straight to the external provider via `Challenge`.

2. **Email-domain-based routing**: When the user enters their email, `@contoso.com` addresses are automatically routed to the AAD provider via `Challenge`.

3. **IdentityProviderRestrictions**: The `spa.app` client has `IdentityProviderRestrictions = { "Google", "local" }`, which includes Google and local login but excludes AAD. The login page respects these restrictions when building the provider list.

4. **Challenge to external provider**: The `ChallengeExternalProvider` method issues a `Challenge` to the appropriate external provider scheme with the `returnUrl` preserved in `AuthenticationProperties.Items`.
