# Consent Page Implementation

Here's a Razor Pages consent page that uses `IIdentityServerInteractionService` to handle consent grant and denial.

## Pages/Consent.cshtml

```cshtml
@page
@model ConsentModel

<h1>Consent</h1>
<p><strong>@Model.ClientName</strong> is requesting access to the following resources:</p>

<form method="post">
    <input type="hidden" asp-for="ReturnUrl" />

    @foreach (var scope in Model.RequestedScopes)
    {
        <div>
            <input type="checkbox" name="ConsentedScopes" value="@scope.Name" checked="@scope.Required" disabled="@scope.Required" />
            @if (scope.Required)
            {
                <input type="hidden" name="ConsentedScopes" value="@scope.Name" />
            }
            <label>@scope.DisplayName - @scope.Description</label>
        </div>
    }

    <div>
        <input type="checkbox" asp-for="RememberConsent" checked="checked" />
        <label asp-for="RememberConsent">Remember my decision</label>
    </div>

    <button type="submit" name="action" value="grant">Allow</button>
    <button type="submit" name="action" value="deny">Deny</button>
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
    public List<string> ConsentedScopes { get; set; } = new();

    [BindProperty]
    public bool RememberConsent { get; set; } = true;

    public string ClientName { get; set; }
    public List<ScopeViewModel> RequestedScopes { get; set; } = new();

    public async Task<IActionResult> OnGet(string returnUrl)
    {
        ReturnUrl = returnUrl;

        // Get the authorization context to display client and scope information
        var context = await _interaction.GetAuthorizationContextAsync(returnUrl);
        if (context == null)
        {
            return RedirectToPage("/Error");
        }

        ClientName = context.Client.ClientName ?? context.Client.ClientId;

        // Build list of requested scopes
        RequestedScopes = context.ValidatedResources.Resources.IdentityResources
            .Select(r => new ScopeViewModel
            {
                Name = r.Name,
                DisplayName = r.DisplayName ?? r.Name,
                Description = r.Description,
                Required = r.Required
            })
            .Union(context.ValidatedResources.Resources.ApiScopes
                .Select(s => new ScopeViewModel
                {
                    Name = s.Name,
                    DisplayName = s.DisplayName ?? s.Name,
                    Description = s.Description,
                    Required = s.Required
                }))
            .ToList();

        return Page();
    }

    public async Task<IActionResult> OnPost(string action)
    {
        var context = await _interaction.GetAuthorizationContextAsync(ReturnUrl);
        if (context == null)
        {
            return RedirectToPage("/Error");
        }

        if (action == "deny")
        {
            // User denied consent — call DenyAuthorizationAsync with AccessDenied
            await _interaction.DenyAuthorizationAsync(context, AuthorizationError.AccessDenied);
            return Redirect(ReturnUrl);
        }

        if (action == "grant")
        {
            // User granted consent — call GrantConsentAsync with selected scopes
            await _interaction.GrantConsentAsync(context, new ConsentResponse
            {
                ScopesValuesConsented = ConsentedScopes,
                RememberConsent = RememberConsent
            });

            // Validate returnUrl before redirecting
            if (await _interaction.IsValidReturnUrl(ReturnUrl))
            {
                return Redirect(ReturnUrl);
            }
        }

        return RedirectToPage("/Error");
    }
}

public class ScopeViewModel
{
    public string Name { get; set; }
    public string DisplayName { get; set; }
    public string Description { get; set; }
    public bool Required { get; set; }
}
```

## Key Points

1. **IIdentityServerInteractionService**: Injected via constructor and used to get authorization context, grant consent, deny authorization, and validate return URLs.

2. **GetAuthorizationContextAsync**: Called to retrieve client and scope details for display on the consent page.

3. **GrantConsentAsync**: Called with a `ConsentResponse` containing `ScopesValuesConsented` (the scopes the user selected) and `RememberConsent = true` for persistent consent.

4. **DenyAuthorizationAsync**: Called with `AuthorizationError.AccessDenied` when the user denies consent.

5. **returnUrl validation**: Uses `_interaction.IsValidReturnUrl(ReturnUrl)` to validate the return URL before redirecting.
