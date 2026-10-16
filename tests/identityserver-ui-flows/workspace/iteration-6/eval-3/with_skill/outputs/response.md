# Consent page

## Program.cs
```csharp
options.UserInteraction.ConsentUrl = "/Consent";   // default is /consent
```
`web.app` has `RequireConsent = true`, so it is redirected here; `spa.app` isn't. For remembered consent to persist, the client also needs `AllowRememberConsent` (default `true`) and optionally `ConsentLifetime`.

## Pages/Consent.cshtml.cs
```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class ConsentModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    public ConsentModel(IIdentityServerInteractionService interaction) => _interaction = interaction;

    public string? ClientName { get; set; }
    public IReadOnlyList<ScopeVm> Scopes { get; set; } = [];

    [BindProperty] public string? ReturnUrl { get; set; }
    [BindProperty] public string[] ScopesConsented { get; set; } = [];
    [BindProperty] public string? Button { get; set; }

    public record ScopeVm(string Name, string? DisplayName, bool Required);

    public async Task<IActionResult> OnGet(string? returnUrl)
    {
        ReturnUrl = returnUrl;
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context is null) return Redirect("~/");   // invalid returnUrl

        Load(context);
        return Page();
    }

    public async Task<IActionResult> OnPost()
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (context is null) return Redirect("~/");   // never redirect to an unvalidated URL

        if (Button == "no")
        {
            await _interaction.DenyAuthorizationAsync(context, AuthorizationError.AccessDenied);
            return Redirect(ReturnUrl!);              // client receives access_denied
        }

        if (Button == "yes" && ScopesConsented.Length > 0)
        {
            await _interaction.GrantConsentAsync(context, new ConsentResponse
            {
                ScopesValuesConsented = ScopesConsented,
                RememberConsent = true               // persist in the grant store
            });
            return Redirect(ReturnUrl!);              // back to /connect/authorize
        }

        ModelState.AddModelError("", "Select at least one permission or deny.");
        Load(context);
        return Page();
    }

    private void Load(AuthorizationRequest context)
    {
        ClientName = context.Client.ClientName ?? context.Client.ClientId;
        var res = context.ValidatedResources.Resources;
        Scopes = res.IdentityResources.Select(r => new ScopeVm(r.Name, r.DisplayName, r.Required))
            .Concat(res.ApiScopes.Select(s => new ScopeVm(s.Name, s.DisplayName, s.Required)))
            .ToList();
    }
}
```

## Consent.cshtml
```html
@page
@model ConsentModel
<h1>@Model.ClientName is requesting access</h1>
<form method="post">
  <input type="hidden" asp-for="ReturnUrl" />
  <ul>
  @foreach (var s in Model.Scopes)
  {
    <li><label>
      <input type="checkbox" name="ScopesConsented" value="@s.Name" checked disabled="@s.Required" />
      @(s.DisplayName ?? s.Name)
    </label>
    @if (s.Required) { <input type="hidden" name="ScopesConsented" value="@s.Name" /> }
    </li>
  }
  </ul>
  <button name="Button" value="yes">Allow</button>
  <button name="Button" value="no">Deny</button>
</form>
```

## Notes
- **Validation**: `GetAuthorizationContextAsync` returns `null` for an invalid returnUrl, so we redirect away instead of trusting it. `IsValidReturnUrl` is an equivalent check.
- **Required scopes**: if the response omits a `Required` scope, IdentityServer returns `access_denied` — hence they're rendered locked.
- Consent is re-prompted when it expires, new scopes appear, or `offline_access` is requested. The consent result between the page and the authorize endpoint is held in a cookie by default (implement `IConsentMessageStore` for custom persistence).
