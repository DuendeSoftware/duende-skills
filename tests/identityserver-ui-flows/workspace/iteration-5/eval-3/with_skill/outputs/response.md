# Consent Page with Razor Pages

The consent page is shown for interactive clients that have `RequireConsent = true` (like `web.app`). It uses `IIdentityServerInteractionService` to read the authorization request, displays the requesting client and requested scopes, and reports the user's decision back to the protocol engine via `GrantConsentAsync` or `DenyAuthorizationAsync`.

## Pages/Consent/Index.cshtml.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace IdentityServer.Pages.Consent;

public class IndexModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;

    public IndexModel(IIdentityServerInteractionService interaction)
    {
        _interaction = interaction;
    }

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public string? ClientName { get; set; }
    public IEnumerable<string> RequestedScopes { get; set; } = Enumerable.Empty<string>();

    [BindProperty]
    public IEnumerable<string> ScopesConsented { get; set; } = Enumerable.Empty<string>();

    [BindProperty]
    public string Button { get; set; } = default!;

    public async Task<IActionResult> OnGet(string? returnUrl)
    {
        ReturnUrl = returnUrl;

        // Get the authorization request to know the client and requested scopes
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context is null)
        {
            return Redirect("~/"); // invalid returnUrl → do not trust it
        }

        ClientName = context.Client.ClientName ?? context.Client.ClientId;
        RequestedScopes = context.ValidatedResources.RawScopeValues;

        return Page();
    }

    public async Task<IActionResult> OnPost(string? returnUrl)
    {
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context is null)
        {
            return Redirect("~/");
        }

        if (Button == "yes")
        {
            // User granted consent for the selected scopes
            await _interaction.GrantConsentAsync(context, new ConsentResponse
            {
                ScopesValuesConsented = ScopesConsented.ToArray(),
                RememberConsent = true
            });
        }
        else
        {
            // User denied consent
            await _interaction.DenyAuthorizationAsync(context, AuthorizationError.AccessDenied);
        }

        // returnUrl was already validated by GetAuthorizationContextAsync returning non-null
        if (await _interaction.IsValidReturnUrl(returnUrl))
        {
            return Redirect(returnUrl!);
        }
        return Redirect("~/");
    }
}
```

## Pages/Consent/Index.cshtml

```html
@page
@model IdentityServer.Pages.Consent.IndexModel

<h1>Consent</h1>
<p><strong>@Model.ClientName</strong> is requesting access to:</p>

<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />

    @foreach (var scope in Model.RequestedScopes)
    {
        <label>
            <input type="checkbox" name="ScopesConsented" value="@scope" checked />
            @scope
        </label>
    }

    <button name="Button" value="yes" type="submit">Allow</button>
    <button name="Button" value="no" type="submit">Deny</button>
</form>
```

## Notes

- **`GetAuthorizationContextAsync`** returns `null` for an invalid/foreign `returnUrl`. Redirecting away when it's `null` is itself the open-redirect protection; the code also re-checks with `IsValidReturnUrl` before the final redirect.
- **Grant** → `GrantConsentAsync(context, new ConsentResponse { ScopesValuesConsented = ..., RememberConsent = true })`. `RememberConsent = true` persists the grant so the user isn't re-prompted next time.
- **Deny** → `DenyAuthorizationAsync(context, AuthorizationError.AccessDenied)` returns `access_denied` to the client.
- The `web.app` client already has `RequireConsent = true`, so this page will be hit; `spa.app` has `RequireConsent = false` and will skip it.
- After either branch, redirecting to `returnUrl` re-issues the authorize request so IdentityServer completes the protocol using the stored consent result.
