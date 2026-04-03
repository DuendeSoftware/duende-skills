# Detecting SAML vs OIDC Requests

To detect if an incoming request is SAML, you could check the return URL or use the interaction service:

```csharp
public class AccountController : Controller
{
    [HttpGet]
    public async Task<IActionResult> Login(string returnUrl)
    {
        // Check if the returnUrl contains SAML indicators
        if (returnUrl?.Contains("/saml/") == true)
        {
            ViewData["IsSaml"] = true;
        }

        // For OIDC, you might use IIdentityServerInteractionService
        // to get the authorization request context

        return View();
    }
}
```

The exact mechanism depends on your SAML library. Some libraries provide an interaction service that can parse the return URL to extract SAML-specific context like the requesting SP and name ID format.
