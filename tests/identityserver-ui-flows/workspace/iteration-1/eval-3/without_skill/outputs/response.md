# Consent Page Implementation

```csharp
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class ConsentModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public ConsentModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    [BindProperty]
    public string ReturnUrl { get; set; }
    [BindProperty]
    public List<string> ConsentedScopes { get; set; } = new();

    public string ClientName { get; set; }
    public IEnumerable<string> Scopes { get; set; }

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context != null)
        {
            ClientName = context.Client.ClientName;
            Scopes = context.ValidatedResources.RawScopeValues;
        }
        return Page();
    }

    public async Task<IActionResult> OnPostAccept()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (context == null) return BadRequest();

        var consent = new ConsentResponse
        {
            ScopesValuesConsented = ConsentedScopes,
            RememberConsent = true
        };

        await _interaction.GrantConsentAsync(context, consent);
        return Redirect(ReturnUrl);
    }

    public async Task<IActionResult> OnPostDeny()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (context == null) return BadRequest();

        await _interaction.DenyAuthorizationAsync(context, AuthorizationError.AccessDenied);
        return Redirect(ReturnUrl);
    }
}
```

This implements a basic consent flow. The interaction service provides the authorization context with client and scope info. Users can grant or deny consent.
