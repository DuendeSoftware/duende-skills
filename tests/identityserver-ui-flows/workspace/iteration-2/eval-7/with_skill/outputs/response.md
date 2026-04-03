# Fixing OIDC State Length and ReturnUrl Preservation

Here's how to fix URL length issues from OIDC state parameters and ensure the `returnUrl` survives the external authentication round-trip.

## Updated Program.cs

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

// Fix #1: Use server-side state storage for the corporate-idp OIDC scheme
// This stores the OIDC state in IDistributedCache instead of the URL,
// fixing URL length issues when the state parameter is too long
builder.Services.AddOidcStateDataFormatterCache("corporate-idp");

// Register the external provider
builder.Services.AddAuthentication()
    .AddOpenIdConnect("corporate-idp", "Corporate IdP", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://corporate-idp.example.com";
        options.ClientId = "your-client-id";
        options.ClientSecret = "your-client-secret";
        options.ResponseType = "code";
        options.CallbackPath = "/signin-corporate";
    });

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Pages/ExternalLogin.cshtml.cs — Challenge with returnUrl preserved

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class ExternalLoginModel : PageModel
{
    public IActionResult OnGet(string returnUrl)
    {
        var callbackUrl = Url.Page("/ExternalLoginCallback");

        // Fix #2: Store returnUrl in AuthenticationProperties.Items
        // This ensures returnUrl survives the entire external authentication round-trip
        var props = new AuthenticationProperties
        {
            RedirectUri = callbackUrl,
            Items =
            {
                { "scheme", "corporate-idp" },
                { "returnUrl", returnUrl }
            }
        };

        return Challenge(props, "corporate-idp");
    }
}
```

## Pages/ExternalLoginCallback.cshtml.cs — Retrieve returnUrl after callback

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
        // Read external identity from the temporary external cookie
        var result = await HttpContext.AuthenticateAsync(
            IdentityServerConstants.ExternalCookieAuthenticationScheme);

        if (result?.Succeeded != true)
        {
            throw new Exception("External authentication error");
        }

        var externalUser = result.Principal;
        var userId = externalUser.FindFirst("sub")?.Value
            ?? externalUser.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

        // Fix #2 (cont.): Retrieve returnUrl from result.Properties.Items
        // This is where we stored it before the Challenge
        var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";
        var scheme = result.Properties.Items["scheme"];

        // Create IdentityServer session
        var isUser = new IdentityServerUser(userId)
        {
            DisplayName = externalUser.FindFirst("name")?.Value ?? "User",
            IdentityProvider = scheme
        };

        await HttpContext.SignInAsync(isUser);

        // Clean up external cookie
        await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

        // Validate returnUrl before redirecting
        if (await _interaction.IsValidReturnUrl(returnUrl) || Url.IsLocalUrl(returnUrl))
        {
            return Redirect(returnUrl);
        }

        return Redirect("~/");
    }
}
```

## Key Points

1. **AddOidcStateDataFormatterCache**: `builder.Services.AddOidcStateDataFormatterCache("corporate-idp")` stores the OIDC state server-side using `IDistributedCache` instead of encoding it in the URL. This fixes URL length issues when the state parameter is too long (>2000 chars).

2. **Storing returnUrl in AuthenticationProperties.Items**: Before calling `Challenge`, the `returnUrl` is stored in `AuthenticationProperties.Items["returnUrl"]`. This dictionary is serialized into the authentication state and survives the entire external redirect round-trip.

3. **Retrieving returnUrl from result.Properties.Items**: In the callback handler, after calling `HttpContext.AuthenticateAsync`, the `returnUrl` is retrieved from `result.Properties.Items["returnUrl"]`.

4. **returnUrl validation**: The `returnUrl` is validated using `_interaction.IsValidReturnUrl` or `Url.IsLocalUrl` before redirecting, protecting against open redirect attacks.
