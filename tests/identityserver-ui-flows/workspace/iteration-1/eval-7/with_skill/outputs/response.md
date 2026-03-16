# Fixing OIDC State Storage and ReturnUrl Preservation

## Problem 1: URL Length Issues — State Parameter Too Long

The OIDC state parameter contains the full authentication properties serialized into the URL. When the state is large, this can exceed URL length limits (>2000 characters). The fix is to use `AddOidcStateDataFormatterCache` which stores the state server-side using `IDistributedCache`.

## Problem 2: ReturnUrl Lost During External Round-Trip

The `returnUrl` must be stored in `AuthenticationProperties.Items` before issuing the Challenge, and retrieved from `result.Properties.Items` after the callback.

## Program.cs — Fix State Storage

```csharp
using Duende.IdentityServer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

builder.Services.AddIdentityServer()
    // ... existing configuration ...
    ;

// Register external OIDC provider
builder.Services.AddAuthentication()
    .AddOpenIdConnect("corporate-idp", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://corporate-idp.example.com";
        options.ClientId = "your-client-id";
        options.ResponseType = "code";
    });

// Fix: Store OIDC state server-side using IDistributedCache instead of the URL
builder.Services.AddOidcStateDataFormatterCache("corporate-idp");

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Pages/ExternalLogin.cshtml.cs — Store ReturnUrl Before Challenge

```csharp
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages;

public class ExternalLoginModel : PageModel
{
    public IActionResult OnGet(string returnUrl)
    {
        var callbackUrl = Url.Page("/ExternalLoginCallback");

        var props = new AuthenticationProperties
        {
            RedirectUri = callbackUrl,
            Items =
            {
                { "scheme", "corporate-idp" },
                { "returnUrl", returnUrl }  // Store returnUrl in Items before Challenge
            }
        };

        return Challenge(props, "corporate-idp");
    }
}
```

## Pages/ExternalLoginCallback.cshtml.cs — Retrieve ReturnUrl After Callback

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
        // Authenticate against the external cookie scheme
        var result = await HttpContext.AuthenticateAsync(
            IdentityServerConstants.ExternalCookieAuthenticationScheme);

        if (result?.Succeeded != true)
            throw new Exception("External authentication error");

        // Retrieve returnUrl from result.Properties.Items
        var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";
        var scheme = result.Properties.Items["scheme"];

        var externalUser = result.Principal;
        var userId = externalUser.FindFirst("sub")?.Value
            ?? externalUser.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

        // Find or provision local user
        // ... user provisioning logic ...

        // Establish IdentityServer session
        var isUser = new IdentityServerUser(userId ?? Guid.NewGuid().ToString())
        {
            IdentityProvider = scheme
        };
        await HttpContext.SignInAsync(isUser);

        // Clean up external cookie
        await HttpContext.SignOutAsync(IdentityServerConstants.ExternalCookieAuthenticationScheme);

        // Validate returnUrl before redirecting
        if (_interaction.IsValidReturnUrl(returnUrl) || Url.IsLocalUrl(returnUrl))
        {
            return Redirect(returnUrl);
        }

        return Redirect("~/");
    }
}
```

### Key Points

1. **`AddOidcStateDataFormatterCache("corporate-idp")`** stores OIDC state server-side using `IDistributedCache`, preventing URL length issues.
2. **ReturnUrl stored before Challenge**: `AuthenticationProperties.Items["returnUrl"]` is set before calling `Challenge`.
3. **ReturnUrl retrieved after callback**: `result.Properties.Items["returnUrl"]` retrieves the preserved URL after authenticating the external cookie.
4. **ReturnUrl validated**: `_interaction.IsValidReturnUrl(returnUrl) || Url.IsLocalUrl(returnUrl)` protects against open redirects.
