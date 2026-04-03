# Azure AD External Identity Provider Integration

Here's how to add Azure AD as an external identity provider with scheme name 'AAD', display name 'Corporate Login', handle the external authentication callback, and clean up properly.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;

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
            RequireConsent = false
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

// Register Azure AD as external identity provider
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://login.microsoftonline.com/{tenant-id}/v2.0";
        options.ClientId = "your-aad-client-id";
        options.ClientSecret = "your-aad-client-secret";
        options.ResponseType = "code";
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.CallbackPath = "/signin-aad";
    });

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Pages/ExternalLogin.cshtml.cs — Trigger Challenge

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class ExternalLoginModel : PageModel
{
    public IActionResult OnGet(string provider, string returnUrl)
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

        return Challenge(props, provider);
    }
}
```

## Pages/ExternalLoginCallback.cshtml.cs — Handle Callback

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class ExternalLoginCallbackModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public ExternalLoginCallbackModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    public async Task<IActionResult> OnGet()
    {
        // 1. Read the external identity from the temporary external cookie
        var result = await HttpContext.AuthenticateAsync(
            IdentityServerConstants.ExternalCookieAuthenticationScheme);

        if (result?.Succeeded != true)
        {
            throw new Exception("External authentication error");
        }

        var externalUser = result.Principal;
        var externalUserId = externalUser.FindFirst("sub")?.Value
            ?? externalUser.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var scheme = result.Properties.Items["scheme"];
        var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";

        // 2. Find or provision a local user based on external identity
        // In production, look up or create a user in your local store
        var localSubjectId = externalUserId; // simplified for demo
        var displayName = externalUser.FindFirst("name")?.Value ?? "External User";

        // 3. Establish IdentityServer session with external IdP recorded
        var isUser = new IdentityServerUser(localSubjectId)
        {
            DisplayName = displayName,
            IdentityProvider = scheme
        };

        await HttpContext.SignInAsync(isUser);

        // 4. Clean up the external cookie
        await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

        // 5. Redirect back to the authorization endpoint
        return Redirect(returnUrl);
    }
}
```

## Key Points

1. **OpenIdConnect registration**: The `AAD` scheme is registered with `SignInScheme` set to `IdentityServerConstants.ExternalCookieAuthenticationScheme`, which stores the external identity in a temporary cookie managed by IdentityServer.

2. **Challenge trigger**: The login page triggers `Challenge("AAD", props)` with `AuthenticationProperties` containing the `returnUrl` in the `Items` dictionary to preserve it across the redirect.

3. **Callback reads external cookie**: `HttpContext.AuthenticateAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme)` reads the temporary external cookie to get the external identity.

4. **External cookie cleanup**: `HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme)` removes the temporary external cookie after processing.

5. **IdentityProvider recorded**: The `IdentityServerUser` is created with `IdentityProvider = scheme` so IdentityServer records which external provider was used.
