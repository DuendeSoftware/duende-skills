# Detecting SAML Requests in the Login Page

To determine whether an incoming request to your login page is a SAML AuthnRequest, you can inspect the authentication context. Here's an approach:

## Checking the Request Type

```csharp
using Microsoft.AspNetCore.Mvc;
using Duende.IdentityServer.Services;

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
            // We have an authentication context
            // Check the protocol type or parameters to determine if it's SAML
            ViewBag.ClientName = context.Client?.ClientName;
            ViewBag.ReturnUrl = returnUrl;
        }

        return View();
    }
}
```

## Determining SAML vs OIDC

The `IIdentityServerInteractionService` provides the authorization context for OIDC requests. For SAML, you might need to:

1. Parse the return URL to check for SAML-specific parameters
2. Check if the request path includes SAML endpoints (like `/saml/signin`)
3. Look at the request's query string or form data for `SAMLRequest` parameters

```csharp
public bool IsSamlRequest(string returnUrl)
{
    return returnUrl?.Contains("/saml/", StringComparison.OrdinalIgnoreCase) == true;
}
```

## Accessing SP Details

Once you've determined it's a SAML request, you can look up the service provider details from your store:

```csharp
// Look up SP by entity ID from the request
var entityId = ExtractEntityIdFromRequest(returnUrl);
var sp = await _serviceProviderStore.FindByEntityIdAsync(entityId);
```

This approach works but requires manual parsing. Check Duende's documentation for any built-in SAML interaction service that might simplify this.