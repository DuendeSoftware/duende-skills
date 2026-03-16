# Consent Page Implementation

Here's a complete consent page implementation using Razor Pages and `IIdentityServerInteractionService`.

## Pages/Consent.cshtml.cs

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

    public string ClientName { get; set; }
    public IEnumerable<string> RequestedScopes { get; set; }

    [BindProperty]
    public string ReturnUrl { get; set; }

    [BindProperty]
    public List<string> ConsentedScopes { get; set; } = new();

    [BindProperty]
    public bool RememberConsent { get; set; } = true;

    [BindProperty]
    public string Button { get; set; }

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;

        // Use IIdentityServerInteractionService to get the authorization context
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context == null)
        {
            return RedirectToPage("/Error");
        }

        ClientName = context.Client.ClientName ?? context.Client.ClientId;
        RequestedScopes = context.ValidatedResources.RawScopeValues;

        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (context == null)
        {
            return RedirectToPage("/Error");
        }

        if (Button == "grant")
        {
            // User grants consent — call GrantConsentAsync with selected scopes
            await _interaction.GrantConsentAsync(context, new ConsentResponse
            {
                ScopesValuesConsented = ConsentedScopes,
                RememberConsent = true
            });
        }
        else if (Button == "deny")
        {
            // User denies consent — call DenyAuthorizationAsync with AccessDenied
            await _interaction.DenyAuthorizationAsync(context, AuthorizationError.AccessDenied);
        }

        // Validate returnUrl before redirecting
        if (await _interaction.IsValidReturnUrl(ReturnUrl))
        {
            return Redirect(ReturnUrl);
        }

        return RedirectToPage("/Error");
    }
}
```

## Pages/Consent.cshtml

```html
@page
@model IdentityServer.Pages.ConsentModel

<h1>Consent</h1>
<p><strong>@Model.ClientName</strong> is requesting access to the following resources:</p>

<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />

    @foreach (var scope in Model.RequestedScopes)
    {
        <div>
            <label>
                <input type="checkbox" name="ConsentedScopes" value="@scope" checked />
                @scope
            </label>
        </div>
    }

    <div>
        <label>
            <input type="checkbox" asp-for="RememberConsent" checked />
            Remember my decision
        </label>
    </div>

    <button type="submit" name="Button" value="grant">Allow</button>
    <button type="submit" name="Button" value="deny">Deny</button>
</form>
```

### Key Points

1. **`IIdentityServerInteractionService`** is injected and used to call `GetAuthorizationContextAsync(returnUrl)` to get client and scope details.
2. **Granting consent**: `GrantConsentAsync` is called with a `ConsentResponse` containing `ScopesValuesConsented` (the scopes the user approved) and `RememberConsent = true`.
3. **Denying consent**: `DenyAuthorizationAsync` is called with `AuthorizationError.AccessDenied`.
4. **returnUrl validation**: The `returnUrl` is validated using `_interaction.IsValidReturnUrl(ReturnUrl)` before redirecting. Additionally, `GetAuthorizationContextAsync` returning non-null confirms the returnUrl is valid.
