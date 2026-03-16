# Detecting SAML AuthnRequests in the Login UI

To detect whether an incoming authentication request is a SAML AuthnRequest (vs. OIDC), use `ISamlInteractionService` from Duende IdentityServer. Inject it into your login controller/page and call `GetRequestContextAsync`.

## Login Controller Example

```csharp
using Duende.IdentityServer.Saml;
using Microsoft.AspNetCore.Mvc;

public class AccountController : Controller
{
    private readonly ISamlInteractionService _samlInteraction;

    public AccountController(ISamlInteractionService samlInteraction)
    {
        _samlInteraction = samlInteraction;
    }

    [HttpGet]
    public async Task<IActionResult> Login(string returnUrl)
    {
        // Check if this is a SAML AuthnRequest
        var samlContext = await _samlInteraction.GetRequestContextAsync(returnUrl);

        if (samlContext != null)
        {
            // This is a SAML authentication request
            var servicProvider = samlContext.ServiceProvider;
            var requestedNameIdFormat = samlContext.RequestedNameIdFormat;

            ViewData["IsSaml"] = true;
            ViewData["SpName"] = servicProvider.DisplayName;
            ViewData["NameIdFormat"] = requestedNameIdFormat;
        }
        else
        {
            // This is an OIDC request (or direct navigation)
            ViewData["IsSaml"] = false;
        }

        return View(new LoginViewModel { ReturnUrl = returnUrl });
    }
}
```

## Razor Page Example

```csharp
using Duende.IdentityServer.Saml;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class LoginModel : PageModel
{
    private readonly ISamlInteractionService _samlInteraction;

    public LoginModel(ISamlInteractionService samlInteraction)
    {
        _samlInteraction = samlInteraction;
    }

    public bool IsSamlRequest { get; set; }
    public string? ServiceProviderName { get; set; }

    public async Task OnGetAsync(string returnUrl)
    {
        var context = await _samlInteraction.GetRequestContextAsync(returnUrl);

        if (context != null)
        {
            IsSamlRequest = true;
            ServiceProviderName = context.ServiceProvider.DisplayName;
            // context.RequestedNameIdFormat — what Name ID format the SP wants
        }
    }
}
```

## Key Points

- **`ISamlInteractionService`** is injected via dependency injection — it's automatically available when you call `.AddSaml()`
- **`GetRequestContextAsync(returnUrl)`** returns a context object if the `returnUrl` corresponds to a SAML AuthnRequest, or `null` if it's not SAML
- **`context.ServiceProvider`** gives you the `SamlServiceProvider` configuration for the requesting SP
- **`context.RequestedNameIdFormat`** tells you what Name ID format the SP requested
- This allows you to customize the login experience based on whether the request is SAML or OIDC
