# Detecting SAML Requests in the Login UI

Use `ISamlInteractionService` to detect whether an incoming authentication request is a SAML `AuthnRequest` and get details about the requesting service provider.

## Implementation

```csharp
// AccountController.cs (or Login Razor Page)
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
            ViewData["SpEntityId"] = servicProvider.EntityId;
            ViewData["NameIdFormat"] = requestedNameIdFormat;
        }
        else
        {
            // This is an OIDC or other type of request
            ViewData["IsSaml"] = false;
        }

        return View();
    }
}
```

## Key Points

- **`ISamlInteractionService`** is injected via dependency injection (automatically registered when `.AddSaml()` is called)
- **`GetRequestContextAsync(returnUrl)`** takes the `returnUrl` parameter from the login page
- Returns `null` if the request is not a SAML AuthnRequest (i.e., it's an OIDC request)
- Returns a context object with `ServiceProvider` (the requesting SP) and `RequestedNameIdFormat` (what NameID format the SP wants)
- This allows you to customize the login experience based on whether the user is authenticating via SAML or OIDC
