# Consent Page for IdentityServer

Below is a Razor Pages implementation of the consent screen. It reads the authorization request, displays the client and requested scopes, and records the user's grant or deny decision.

## Pages/Consent/Index.cshtml.cs

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

    [BindProperty(SupportsGet = true)] public string ReturnUrl { get; set; }
    [BindProperty] public List<string> ScopesConsented { get; set; } = new();
    [BindProperty] public string Decision { get; set; }

    public string ClientName { get; set; }
    public IEnumerable<string> Scopes { get; set; }

    public async Task<IActionResult> OnGetAsync(string returnUrl)
    {
        ReturnUrl = returnUrl;
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context == null)
        {
            return RedirectToPage("/Error");
        }

        ClientName = context.Client.ClientName;
        Scopes = context.ValidatedResources.RawScopeValues;
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (context == null)
        {
            return RedirectToPage("/Error");
        }

        if (Decision == "allow")
        {
            var response = new ConsentResponse
            {
                ScopesConsented = ScopesConsented,
                RememberConsent = true
            };
            await _interaction.GrantConsentAsync(context, response);
        }
        else
        {
            await _interaction.DenyAuthorizationAsync(context, AuthorizationError.AccessDenied);
        }

        return Redirect(ReturnUrl);
    }
}
```

## Pages/Consent/Index.cshtml

```html
@page
@model ConsentModel

<h2>@Model.ClientName is requesting access</h2>

<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />
    @foreach (var scope in Model.Scopes)
    {
        <label><input type="checkbox" name="ScopesConsented" value="@scope" checked /> @scope</label>
    }
    <button name="Decision" value="allow">Allow</button>
    <button name="Decision" value="deny">Deny</button>
</form>
```

## Notes

- `GetAuthorizationContextAsync` returns the client and requested scopes. If it returns `null`, the `returnUrl` is not a valid authorization request, so redirect away rather than trusting it.
- On grant, call `GrantConsentAsync` with a `ConsentResponse` and set `RememberConsent = true` to persist the decision.
- On deny, call `DenyAuthorizationAsync` with `AuthorizationError.AccessDenied`.
- Only the `web.app` client has `RequireConsent = true`, so only it will hit this page.
