# Consent page

**Program.cs**
```csharp
options.UserInteraction.ConsentUrl = "/Consent";
```

**Pages/Consent.cshtml.cs**
```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class ConsentModel : PageModel
{
    private readonly IIdentityServerInteractionService _interaction;
    public ConsentModel(IIdentityServerInteractionService interaction) => _interaction = interaction;

    public string? ClientName { get; set; }
    public IEnumerable<string> IdentityScopes { get; set; } = [];
    public IEnumerable<string> ApiScopes { get; set; } = [];

    [BindProperty] public string? ReturnUrl { get; set; }
    [BindProperty] public string[] ScopesConsented { get; set; } = [];
    [BindProperty] public string Button { get; set; } = "";

    public async Task<IActionResult> OnGetAsync(string returnUrl)
    {
        ReturnUrl = returnUrl;
        var request = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (request == null) return RedirectToPage("/Error");

        ClientName = request.Client.ClientName ?? request.Client.ClientId;
        IdentityScopes = request.ValidatedResources.Resources.IdentityResources.Select(r => r.Name);
        ApiScopes = request.ValidatedResources.ParsedScopes.Select(s => s.ParsedName);
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        var request = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (request == null) return RedirectToPage("/Error");

        ConsentResponse? grant = null;
        if (Button == "no")
        {
            grant = new ConsentResponse { Error = AuthorizationError.AccessDenied };
        }
        else if (Button == "yes")
        {
            grant = new ConsentResponse
            {
                RememberConsent = true,
                ScopesValuesConsented = ScopesConsented
            };
        }

        if (grant != null)
        {
            await _interaction.GrantConsentAsync(request, grant);
            return Redirect(ReturnUrl!);
        }
        return Page();
    }
}
```
For denial you can also use `_interaction.DenyAuthorizationAsync(request, AuthorizationError.AccessDenied)`.

**Consent.cshtml**
```html
@page
@model ConsentModel
<h1>@Model.ClientName is requesting access</h1>
<form method="post">
  <input type="hidden" asp-for="ReturnUrl" />
  <ul>
  @foreach (var s in Model.IdentityScopes.Concat(Model.ApiScopes)) {
    <li><label><input type="checkbox" name="ScopesConsented" value="@s" checked /> @s</label></li>
  }
  </ul>
  <button name="Button" value="yes">Allow</button>
  <button name="Button" value="no">Deny</button>
</form>
```

**returnUrl validation:** `GetAuthorizationContextAsync` returns null for URLs it doesn't recognise; we bail out in that case, so only validated URLs get redirected to.
