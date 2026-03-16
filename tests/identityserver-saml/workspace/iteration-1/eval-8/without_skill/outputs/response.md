# Detecting SAML Requests in the Login Page

To detect if an incoming request is a SAML AuthnRequest versus a standard OIDC request, you can check the return URL parameters.

## Approach

You can use the `IIdentityServerInteractionService` to get the authorization context and check if it's a SAML request:

```csharp
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc;

public class AccountController : Controller
{
    private readonly IIdentityServerInteractionService _interaction;

    public AccountController(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    [HttpGet]
    public async Task<IActionResult> Login(string returnUrl)
    {
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);

        if (context != null)
        {
            // This is an authentication request
            // Check parameters to determine if it's SAML
            var isSaml = returnUrl?.Contains("/saml/") == true;

            if (isSaml)
            {
                // Handle SAML-specific login logic
                ViewData["IsSaml"] = true;
            }
        }

        return View(new LoginViewModel { ReturnUrl = returnUrl });
    }
}
```

## Key Points

- Use the interaction service to get context about the authentication request
- Check the return URL to determine if it's a SAML flow
- You can customize the login UI based on the request type
- Both OIDC and SAML flows share the same login page in IdentityServer
