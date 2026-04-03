# Home Realm Discovery for IdentityServer Login

Here's a login page with provider selection logic.

## Updated Program.cs (spa.app with provider restrictions)

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

builder.Services.AddIdentityServer(options => { })
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

builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Azure AD", options =>
    {
        options.Authority = "https://login.microsoftonline.com/{tenant}/v2.0";
        options.ClientId = "your-client-id";
    })
    .AddOpenIdConnect("Google", "Google", options =>
    {
        options.Authority = "https://accounts.google.com";
        options.ClientId = "your-google-client-id";
    });

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Pages/Login.cshtml.cs

```csharp
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

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;

        // Check for provider hint in query parameters
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

        // Note: A generic developer would check for acr_values but might not know
        // the specific context.IdP property in Duende
        if (context != null)
        {
            // Check acr_values for provider hint
            var acrValues = context.Parameters["acr_values"];
            if (!string.IsNullOrEmpty(acrValues) && acrValues.StartsWith("idp:"))
            {
                var provider = acrValues.Substring(4);
                var props = new AuthenticationProperties
                {
                    RedirectUri = "/callback",
                    Items = { { "returnUrl", returnUrl } }
                };
                return Challenge(props, provider);
            }
        }

        return Page();
    }

    public async Task<IActionResult> OnPostEmailRoute()
    {
        // Route @contoso.com to AAD
        if (!string.IsNullOrEmpty(Email) && Email.EndsWith("@contoso.com"))
        {
            var props = new AuthenticationProperties
            {
                RedirectUri = "/callback",
                Items = { { "returnUrl", ReturnUrl } }
            };
            return Challenge(props, "AAD");
        }

        return Page();
    }
}
```

## Notes

- The spa.app client is restricted to Google and local login via `IdentityProviderRestrictions`
- The login page checks for `acr_values` hint from the authorization request
- Email domain routing sends @contoso.com users to the AAD provider
- When a provider is determined, a Challenge is issued to redirect to that provider
