# Consent Page for IdentityServer

Here's a consent page implementation using Razor Pages and the interaction service.

## Pages/Consent.cshtml

```cshtml
@page
@model ConsentModel

<h1>Application Access</h1>
<p>@Model.ClientName would like to access your account.</p>

<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />

    @foreach (var scope in Model.Scopes)
    {
        <div>
            <input type="checkbox" name="SelectedScopes" value="@scope" checked />
            <label>@scope</label>
        </div>
    }

    <button type="submit" name="button" value="yes">Allow</button>
    <button type="submit" name="button" value="no">Deny</button>
</form>
```

## Pages/Consent.cshtml.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
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
    public List<string> SelectedScopes { get; set; } = new();

    public string ClientName { get; set; }
    public List<string> Scopes { get; set; } = new();

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;

        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context == null)
        {
            return RedirectToPage("/Error");
        }

        ClientName = context.Client.ClientName ?? context.Client.ClientId;
        Scopes = context.ValidatedResources.ParsedScopes.Select(s => s.ParsedName).ToList();

        return Page();
    }

    public async Task<IActionResult> OnPost(string button)
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (context == null)
        {
            return RedirectToPage("/Error");
        }

        if (button == "no")
        {
            // Deny consent - use ConsentResponse with error
            await _interaction.GrantConsentAsync(context, new ConsentResponse
            {
                Error = AuthorizationError.AccessDenied
            });
            return Redirect(ReturnUrl);
        }

        if (button == "yes")
        {
            await _interaction.GrantConsentAsync(context, new ConsentResponse
            {
                ScopesValuesConsented = SelectedScopes
            });

            return Redirect(ReturnUrl);
        }

        return Page();
    }
}
```

## Notes

- The consent page displays the requesting client name and requested scopes
- Users can select which scopes to grant and submit their decision
- When denied, a ConsentResponse with an AccessDenied error is sent
- When granted, the selected scopes are passed in the ConsentResponse
