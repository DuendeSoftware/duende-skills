# Detecting SAML AuthnRequests in the Login UI

To detect whether an incoming authentication request is a SAML AuthnRequest and access details about the requesting service provider, use `ISamlInteractionService`.

## Injecting and Using ISamlInteractionService

```csharp
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc;

public class AccountController : Controller
{
    private readonly ISamlInteractionService _samlInteraction;
    private readonly IIdentityServerInteractionService _interaction;

    public AccountController(
        ISamlInteractionService samlInteraction,
        IIdentityServerInteractionService interaction)
    {
        _samlInteraction = samlInteraction;
        _interaction = interaction;
    }

    [HttpGet]
    public async Task<IActionResult> Login(string returnUrl)
    {
        // Check if this is a SAML AuthnRequest
        var samlContext = await _samlInteraction.GetRequestContextAsync(returnUrl);

        if (samlContext != null)
        {
            // This is a SAML authentication request
            var serviceProvider = samlContext.ServiceProvider;
            var requestedNameIdFormat = samlContext.RequestedNameIdFormat;

            ViewBag.IsSaml = true;
            ViewBag.SpDisplayName = serviceProvider.DisplayName;
            ViewBag.SpEntityId = serviceProvider.EntityId;
            ViewBag.NameIdFormat = requestedNameIdFormat;
        }
        else
        {
            // Check if it's an OIDC request instead
            var oidcContext = await _interaction.GetAuthorizationContextAsync(returnUrl);
            if (oidcContext != null)
            {
                ViewBag.IsSaml = false;
                ViewBag.ClientName = oidcContext.Client.ClientName;
            }
        }

        return View();
    }
}
```

## How It Works

1. **Inject `ISamlInteractionService`** via constructor injection
2. **Call `GetRequestContextAsync(returnUrl)`** with the return URL from the login page
3. **Check if the result is non-null** — if it's not null, the request originated from a SAML AuthnRequest
4. **Access SP details** via the context:
   - `context.ServiceProvider` — the full `SamlServiceProvider` model (EntityId, DisplayName, etc.)
   - `context.RequestedNameIdFormat` — the Name ID format requested by the SP

## Razor Pages Example

If you're using Razor Pages instead of MVC:

```csharp
public class LoginModel : PageModel
{
    private readonly ISamlInteractionService _samlInteraction;

    public LoginModel(ISamlInteractionService samlInteraction)
    {
        _samlInteraction = samlInteraction;
    }

    public bool IsSamlRequest { get; set; }
    public string? ServiceProviderName { get; set; }

    public async Task<IActionResult> OnGetAsync(string returnUrl)
    {
        var samlContext = await _samlInteraction.GetRequestContextAsync(returnUrl);

        if (samlContext != null)
        {
            IsSamlRequest = true;
            ServiceProviderName = samlContext.ServiceProvider.DisplayName;
        }

        return Page();
    }
}
```

## Key Points

- `ISamlInteractionService` is automatically registered when you call `.AddSaml()`
- Use it alongside `IIdentityServerInteractionService` (for OIDC) to handle both protocol types in a unified login page
- The `returnUrl` parameter is the same one ASP.NET Core's authentication middleware provides to your login page