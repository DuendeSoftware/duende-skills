# Adding Azure AD as an External Identity Provider

## 1. Register Azure AD in Program.cs

```csharp
using Duende.IdentityServer;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;

// Program.cs
builder.Services.AddAuthentication()
    .AddOpenIdConnect("AAD", "Corporate Login", options =>
    {
        options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
        options.Authority = "https://login.microsoftonline.com/{tenant-id}/v2.0";
        options.ClientId = "your-aad-client-id";
        options.ClientSecret = "your-aad-client-secret";
        options.ResponseType = "code";
        options.CallbackPath = "/signin-aad";
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");
    });
```

The `SignInScheme` is set to `IdentityServerConstants.ExternalCookieAuthenticationScheme`. This tells the OIDC handler to store the external identity in a temporary cookie managed by IdentityServer, rather than the main application cookie.

## 2. Trigger External Login

```csharp
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

        return Challenge(props, provider);  // Challenge with "AAD"
    }
}
```

The `returnUrl` is stored in `AuthenticationProperties.Items` so it survives the external authentication round-trip. The `Challenge` call redirects the user to Azure AD.

## 3. Handle the Callback

```csharp
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
            throw new Exception("External authentication failed");
        }

        var externalUser = result.Principal;
        var externalId = externalUser.FindFirst("sub")?.Value
            ?? externalUser.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var scheme = result.Properties.Items["scheme"];
        var returnUrl = result.Properties.Items["returnUrl"] ?? "~/";

        // 2. Find or provision local user
        var localUser = FindOrProvisionUser(scheme, externalId, externalUser.Claims);

        // 3. Establish the IdentityServer session with external IdP recorded
        var isUser = new IdentityServerUser(localUser.SubjectId)
        {
            DisplayName = localUser.DisplayName,
            IdentityProvider = scheme  // Records which external IdP was used
        };

        await HttpContext.SignInAsync(isUser);

        // 4. Clean up the external cookie
        await HttpContext.SignOutAsync(
            IdentityServerConstants.ExternalCookieAuthenticationScheme);

        // 5. Redirect back to IdentityServer protocol processing
        return Redirect(returnUrl);
    }
}
```

## Key Points

- **SignInScheme**: `IdentityServerConstants.ExternalCookieAuthenticationScheme` is used as the temporary cookie scheme for external authentication. This separates the external identity from the main IdentityServer session.
- **IdentityProvider**: Setting `IdentityProvider = scheme` on the `IdentityServerUser` records which external IdP authenticated the user. This is stored in the `idp` claim of the session.
- **Cookie Cleanup**: Always call `SignOutAsync` on `ExternalCookieAuthenticationScheme` after processing to remove the temporary external cookie.
- **returnUrl Preservation**: The `returnUrl` is stored in `AuthenticationProperties.Items` before the Challenge and retrieved from `result.Properties.Items` in the callback.
