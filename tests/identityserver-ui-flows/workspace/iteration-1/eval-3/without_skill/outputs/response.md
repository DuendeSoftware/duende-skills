# Consent Page for IdentityServer

Here's how to implement a consent page using Razor Pages.

## Pages/Consent.cshtml.cs

```csharp
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
    public IEnumerable<string> Scopes { get; set; }

    [BindProperty]
    public string ReturnUrl { get; set; }

    [BindProperty]
    public List<string> SelectedScopes { get; set; } = new();

    [BindProperty]
    public string Action { get; set; }

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;

        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context == null)
            return RedirectToPage("/Error");

        ClientName = context.Client.ClientName;
        Scopes = context.ValidatedResources.RawScopeValues;

        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (context == null)
            return RedirectToPage("/Error");

        if (Action == "allow")
        {
            // Grant consent with selected scopes
            var consent = new Duende.IdentityServer.Models.ConsentResponse
            {
                ScopesValuesConsented = SelectedScopes,
                RememberConsent = true
            };
            await _interaction.GrantConsentAsync(context, consent);
        }
        else
        {
            // Deny consent
            await _interaction.DenyAuthorizationAsync(context,
                Duende.IdentityServer.Models.AuthorizationError.AccessDenied);
        }

        return Redirect(ReturnUrl);
    }
}
```

## Pages/Consent.cshtml

```html
@page
@model IdentityServer.Pages.ConsentModel

<h1>Consent</h1>
<p><strong>@Model.ClientName</strong> wants access to:</p>

<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />

    @foreach (var scope in Model.Scopes)
    {
        <div>
            <input type="checkbox" name="SelectedScopes" value="@scope" checked />
            <label>@scope</label>
        </div>
    }

    <button type="submit" name="Action" value="allow">Allow</button>
    <button type="submit" name="Action" value="deny">Deny</button>
</form>
```

### Notes

- Use `IIdentityServerInteractionService` to get the authorization context and handle consent.
- Call `GrantConsentAsync` with the user's scope selections.
- Call `DenyAuthorizationAsync` when the user denies access.
