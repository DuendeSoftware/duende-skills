# External Identity Provider: Azure AD with IdentityServer

Here's a complete implementation for adding Azure AD as an external identity provider.

## Program.cs — Register the External Provider

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

builder.Services.AddIdentityServer(options =>
    {
        // existing configuration...
    })
    // ... existing client/resource configuration ...
    .AddTestUsers(new List<Duende.IdentityServer.Test.TestUser>());

// Register Azure AD as an external identity provider
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://login.microsoftonline.com/{tenant-id}/v2.0";
        options.ClientId = builder.Configuration["AzureAd:ClientId"];
        options.ClientSecret = builder.Configuration["AzureAd:ClientSecret"];
        options.ResponseType = "code";
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");
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

## Pages/ExternalLogin.cshtml.cs — Trigger External Authentication

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages;

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

        // Issue a Challenge to the AAD provider, storing returnUrl in AuthenticationProperties.Items
        return Challenge(props, provider);
    }
}
```

## Pages/ExternalLoginCallback.cshtml.cs — Handle the Callback

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages;

public class ExternalLoginCallbackModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public ExternalLoginCallbackModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    public async Task<IActionResult> OnGet()
    {
        // 1. Read the external identity from the temporary cookie
        var result = await HttpContext.AuthenticateAsync(
            IdentityServerConstants.ExternalCookieAuthenticationScheme);

        if (result?.Succeeded != true)
        {
            throw new Exception("External authentication error");
        }

        var externalUser = result.Principal;
        var externalId = externalUser.FindFirst("sub")?.Value
            ?? externalUser.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var scheme = result.Properties.Items["scheme"];
        var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";

        // 2. Find or provision a local user based on the external identity
        var localUser = FindOrProvisionUser(scheme, externalId, externalUser);

        // 3. Establish the IdentityServer session with the external IdP recorded
        var isUser = new IdentityServerUser(localUser.SubjectId)
        {
            DisplayName = localUser.DisplayName,
            IdentityProvider = scheme  // Record the external IdP in the session
        };
        await HttpContext.SignInAsync(isUser);

        // 4. Clean up the external cookie
        await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

        // 5. Redirect back to the authorization endpoint
        return Redirect(returnUrl);
    }

    private LocalUser FindOrProvisionUser(string scheme, string externalId, System.Security.Claims.ClaimsPrincipal externalUser)
    {
        // Look up by external provider + external ID
        // If not found, create a new local user
        return new LocalUser
        {
            SubjectId = Guid.NewGuid().ToString(),
            DisplayName = externalUser.FindFirst("name")?.Value ?? "Unknown"
        };
    }
}

public class LocalUser
{
    public string SubjectId { get; set; }
    public string DisplayName { get; set; }
}
```

### Key Points

1. **SignInScheme**: The OpenIdConnect handler's `SignInScheme` is set to `IdentityServerConstants.ExternalCookieAuthenticationScheme` — this stores the external identity in a temporary cookie.
2. **Challenge**: The external login trigger calls `Challenge` with `"AAD"` and stores `returnUrl` in `AuthenticationProperties.Items`.
3. **Callback reads external cookie**: The callback calls `HttpContext.AuthenticateAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme)` to read the external identity.
4. **IdentityProvider recorded**: The `IdentityServerUser` has `IdentityProvider = scheme` set to record which external IdP was used.
5. **Cookie cleanup**: `HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme)` cleans up the temporary external cookie.
