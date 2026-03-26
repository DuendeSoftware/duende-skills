# Consent Page Implementation

## Consent.cshtml.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages;

public class ConsentModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public ConsentModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    [BindProperty]
    public string ReturnUrl { get; set; } = string.Empty;

    [BindProperty]
    public List<string> SelectedScopes { get; set; } = new();

    public string ClientName { get; set; } = string.Empty;
    public IEnumerable<string> RequestedScopes { get; set; } = Enumerable.Empty<string>();

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;

        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context == null)
        {
            return RedirectToPage("/Error");
        }

        ClientName = context.Client.ClientName ?? context.Client.ClientId;
        RequestedScopes = context.ValidatedResources.RawScopeValues;

        return Page();
    }

    public async Task<IActionResult> OnPostGrant()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (context == null)
        {
            return RedirectToPage("/Error");
        }

        // Grant consent with selected scopes
        await _interaction.GrantConsentAsync(context, new ConsentResponse
        {
            ScopesValuesConsented = SelectedScopes,
            RememberConsent = true
        });

        // Validate returnUrl before redirecting
        if (await _interaction.IsValidReturnUrl(ReturnUrl))
        {
            return Redirect(ReturnUrl);
        }

        return RedirectToPage("/Error");
    }

    public async Task<IActionResult> OnPostDeny()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (context == null)
        {
            return RedirectToPage("/Error");
        }

        // Deny consent
        await _interaction.DenyAuthorizationAsync(context, AuthorizationError.AccessDenied);

        // Validate returnUrl before redirecting
        if (await _interaction.IsValidReturnUrl(ReturnUrl))
        {
            return Redirect(ReturnUrl);
        }

        return RedirectToPage("/Error");
    }
}
```

## Key Design Decisions

1. **GetAuthorizationContextAsync**: Used to retrieve the client and requested scopes from the returnUrl.
2. **GrantConsentAsync**: Called with `ScopesValuesConsented` containing the user-selected scopes and `RememberConsent = true` to persist consent for future requests.
3. **DenyAuthorizationAsync**: Called with `AuthorizationError.AccessDenied` when the user denies consent.
4. **returnUrl validation**: Uses `IsValidReturnUrl` before redirecting to prevent open redirect attacks.
